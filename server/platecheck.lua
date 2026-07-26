-- ============================================================================
--  platecheck.lua  —  ANPR / radar plate lookups
-- ----------------------------------------------------------------------------
--  Bridges a plate scanner (radar, ANPR camera, /checkplate command) to
--  everything the MDT already knows about a vehicle, and pushes a targeted
--  ps-dispatch alert to the scanning officer when something is worth stopping
--  for.
--
--  Usage from any server script:
--
--      -- look up + alert the officer (job-checked):
--      exports['ps-mdt']:PlateCheckAlert(source, 'ABC123', coords)
--
--      -- lookup only; pass source to apply the same job check:
--      local result = exports['ps-mdt']:CheckPlate('ABC123', source)
--      -- result.hits[] / result.severity / result.owner / result.model
--      -- result.denied is true when the player was not allowed to query
--
--  BUILT FOR CONTINUOUS SCANNING. A radar loop may call these every tick for
--  every vehicle around an officer; three mechanisms keep that off the
--  database and out of the officer's face:
--
--    1. A short-lived result cache — the same plate is answered from memory.
--    2. In-flight coalescing — concurrent lookups of one plate share a single
--       query instead of each starting their own.
--    3. Per-officer, per-plate alert cooldowns plus a hard alerts-per-minute
--       ceiling, so a busy street cannot bury the officer in cards.
--
--  Both exports must be called from inside a coroutine (CreateThread), which
--  is already true for anything using MySQL awaits.
-- ============================================================================

local resourceName = tostring(GetCurrentResourceName())

--- Severity of the worst hit decides the alert's urgency.
local SEVERITY_RANK = { critical = 2, warning = 1 }

---@param name string
---@return table cfg  Per-check configuration with sane defaults
local function checkCfg(name)
    local root = Config.PlateCheck or {}
    local checks = root.checks or {}
    return checks[name] or {}
end

---@param name string
---@return boolean
local function checkEnabled(name)
    return checkCfg(name).enabled ~= false
end

---@param name string
---@param default string
---@return string
local function checkSeverity(name, default)
    local sev = checkCfg(name).severity
    return (sev == 'critical' or sev == 'warning') and sev or default
end

---@param key string
---@param fallback number
---@return number
local function tuning(key, fallback)
    return tonumber((Config.PlateCheck or {})[key]) or fallback
end

--- Truthiness across the shapes the DB columns actually arrive in: MariaDB
--- hands back 1/0, older rows may hold '1'/'true', and oxmysql can return a
--- real boolean.
---@param value any
---@return boolean
local function isTruthy(value)
    if type(value) == 'boolean' then return value end
    if type(value) == 'number' then return value ~= 0 end
    if type(value) == 'string' then
        local lowered = value:lower()
        return lowered == '1' or lowered == 'true' or lowered == 'yes'
    end
    return false
end

--- Canonical form of a plate, used as the cache key.
---@param plate any
---@return string|nil
local function normalizePlate(plate)
    if type(plate) ~= 'string' and type(plate) ~= 'number' then return nil end
    local text = tostring(plate):gsub('%s+', ''):upper()
    if text == '' then return nil end
    return text
end

--- The plate forms a query should compare against.
---
--- CRITICAL for anything running in a loop: the comparison has to touch the
--- column RAW. Wrapping it in UPPER()/REPLACE() makes MariaDB unable to use
--- player_vehicles.plate, mdt_bolos.subject_id or idx_impound_plate and it
--- full-scans those tables instead — unnoticeable for one manual lookup,
--- fatal for a scanner querying continuously on a populated server.
---
--- Transforming the INPUT instead keeps the indexes in play. Two forms cover
--- how plates are actually stored: these tables are utf8mb4_general_ci, which
--- compares case-insensitively AND ignores trailing spaces, so a trimmed
--- value already matches a padded stored one. The second candidate preserves
--- internal spaces for plates that legitimately contain them.
---@param plate any
---@return string|nil normalized, table candidates
local function plateCandidates(plate)
    local normalized = normalizePlate(plate)
    if not normalized then return nil, {} end
    local spaced = tostring(plate):gsub('^%s+', ''):gsub('%s+$', ''):upper()
    if spaced == '' or spaced == normalized then
        -- IN (?, ?) with both slots filled keeps one prepared statement shape.
        return normalized, { normalized, normalized }
    end
    return normalized, { normalized, spaced }
end

--- "3 days ago" from a unix timestamp. Recency is what makes a count mean
--- something: four impounds last year is history, four this week is a habit.
---@param unixSeconds number|nil
---@return string|nil
local function relativeAge(unixSeconds)
    local ts = tonumber(unixSeconds)
    if not ts or ts <= 0 then return nil end
    local days = math.floor((os.time() - ts) / 86400)
    if days <= 0 then return 'today' end
    if days == 1 then return 'yesterday' end
    if days < 14 then return days .. ' days ago' end
    if days < 60 then return math.floor(days / 7) .. ' weeks ago' end
    return math.floor(days / 30) .. ' months ago'
end

--- May this player run plate checks?
-- CheckAuth is the codebase's baseline (it also fails closed on an offline or
-- invalid source), but it accepts EMS and DOJ as well — both have MDT access
-- and neither has any business running plates. So the job type is narrowed on
-- top of it, defaulting to police only.
---@param src number
---@return boolean
local function mayRunPlateCheck(src)
    if not CheckAuth(src) then return false end

    local allowed = (Config.PlateCheck or {}).allowedJobTypes
    if allowed == false then return true end -- explicitly: anyone CheckAuth accepts
    if type(allowed) ~= 'table' or #allowed == 0 then
        allowed = { Config.PoliceJobType }
    end

    local ok, jobType = pcall(ps.getJobType, src)
    if not ok then return false end
    for _, allowedType in ipairs(allowed) do
        if allowedType == jobType then return true end
    end
    return false
end

-- ── The lookup ───────────────────────────────────────────────────────────────

--- Everything the MDT knows about one plate, in exactly two round trips.
--- Only ever called through cachedLookup(), never directly.
---@param normalized string
---@return table
local function runPlateQueries(normalized, candidates)
    local result = { plate = normalized, found = false, hits = {} }
    local c1, c2 = candidates[1], candidates[2]

    ---@param forcedSeverity string|nil Overrides the configured severity for
    --- checks that escalate on their own (impound history), which otherwise
    --- would be flattened back to the config value.
    local function addHit(key, label, detail, defaultSeverity, forcedSeverity)
        if not checkEnabled(key) then return end
        result.hits[#result.hits + 1] = {
            key = key,
            label = label,
            detail = detail,
            severity = forcedSeverity or checkSeverity(key, defaultSeverity),
        }
    end

    -- Query 1: the vehicle and its owner's name in one go. The REPLACE strips
    -- the trailing spaces GTA pads plates with; both sides are upper-cased so
    -- the comparison never depends on how a framework stored the plate.
    local vehicle = MySQL.single.await([[
        SELECT pv.id, pv.plate, pv.vehicle, pv.citizenid, pv.state AS core_state,
               pv.mdt_vehicle_stolen      AS stolen,
               pv.mdt_vehicle_boloactive  AS boloactive,
               pv.mdt_vehicle_information AS information,
               JSON_UNQUOTE(JSON_EXTRACT(p.charinfo, '$.firstname')) AS firstname,
               JSON_UNQUOTE(JSON_EXTRACT(p.charinfo, '$.lastname'))  AS lastname,
               JSON_EXTRACT(p.metadata, '$.licences.driver')          AS driver_licence
        FROM player_vehicles pv
        LEFT JOIN players p ON p.citizenid = pv.citizenid
        WHERE pv.plate IN (?, ?)
        LIMIT 1
    ]], { c1, c2 })

    if not vehicle then
        vehicle = MySQL.single.await([[
            SELECT pv.id, pv.plate, pv.vehicle, pv.citizenid, pv.state AS core_state,
                   pv.mdt_vehicle_stolen      AS stolen,
                   pv.mdt_vehicle_boloactive  AS boloactive,
                   pv.mdt_vehicle_information AS information,
                   JSON_UNQUOTE(JSON_EXTRACT(p.charinfo, '$.firstname')) AS firstname,
                   JSON_UNQUOTE(JSON_EXTRACT(p.charinfo, '$.lastname'))  AS lastname,
                   JSON_EXTRACT(p.metadata, '$.licences.driver')          AS driver_licence
            FROM player_vehicles pv
            LEFT JOIN players p ON p.citizenid = pv.citizenid
            WHERE REPLACE(pv.plate, ' ', '') = ?
            LIMIT 1
        ]], { normalized })
    end

    local vehicleId = vehicle and vehicle.id or -1
    local ownerCid = vehicle and vehicle.citizenid or nil

    local c3 = (vehicle and type(vehicle.plate) == 'string' and vehicle.plate ~= '')
        and vehicle.plate:gsub('^%s+', ''):gsub('%s+$', '')
        or c1

    local facts = MySQL.single.await([[
        SELECT
            (SELECT COUNT(*) FROM mdt_bolos
              WHERE type = 'vehicle' AND status = 'active'
                AND subject_id IN (?, ?, ?))                                  AS bolo_count,
            (SELECT notes FROM mdt_bolos
              WHERE type = 'vehicle' AND status = 'active'
                AND subject_id IN (?, ?, ?) LIMIT 1)                          AS bolo_notes,
            (SELECT COUNT(*) FROM mdt_impound
              WHERE vehicleid = ? OR plate IN (?, ?, ?))                      AS impound_total,
            (SELECT MAX(`time`) FROM mdt_impound
              WHERE vehicleid = ? OR plate IN (?, ?, ?))                      AS impound_last,
            (SELECT COUNT(*) FROM mdt_impound
              WHERE status = 'active'
                AND (vehicleid = ? OR plate IN (?, ?, ?)))                    AS impound_held,
            (SELECT COUNT(*) FROM mdt_reports_warrants
              WHERE citizenid = ? AND expirydate >= NOW())                    AS warrant_count
    ]], {
        c1, c2, c3,
        c1, c2, c3,
        vehicleId, c1, c2, c3,
        vehicleId, c1, c2, c3,
        vehicleId, c1, c2, c3,
        ownerCid or '',
    }) or {}

    if vehicle then
        result.found = true
        if c3 and c3 ~= '' then result.plate = c3 end
        result.spawnName = vehicle.vehicle
        result.model = VehicleDisplayName and VehicleDisplayName(vehicle.vehicle) or vehicle.vehicle
        result.ownerCitizenid = vehicle.citizenid

        local name = ((vehicle.firstname or '') .. ' ' .. (vehicle.lastname or ''))
            :gsub('^%s+', ''):gsub('%s+$', '')
        if name ~= '' then result.owner = name end
        if not result.owner and ownerCid then
            result.owner = ps.getPlayerNameByIdentifier(ownerCid) or nil
        end

        if isTruthy(vehicle.stolen) then
            addHit('stolen', 'Reported stolen', vehicle.information, 'critical')
        end

        if ownerCid and (tonumber(facts.warrant_count) or 0) > 0 then
            local total = tonumber(facts.warrant_count)
            addHit('warrants', 'Owner wanted',
                ('%d active warrant%s'):format(total, total == 1 and '' or 's'), 'critical')
        end

        if checkEnabled('driverLicense') and ownerCid then
            local licence = vehicle.driver_licence
            local text = licence ~= nil and tostring(licence):lower() or nil
            if text and text ~= 'null' and not isTruthy(licence) then
                addHit('driverLicense', 'Owner has no driver licence', nil, 'warning')
            end
        end

        -- Impound HISTORY rather than a yes/no. One impound is unremarkable;
        -- a car that keeps ending up in the lot is a pattern an officer wants
        -- before walking up to it. Counted on the vehicle row AND the plate,
        -- so records survive a vehicle being re-created under a new id.
        if checkEnabled('impounds') then
            local cfg = checkCfg('impounds')
            local total = tonumber(facts.impound_total) or 0
            -- core_state 2 means another resource parked it in a lot without
            -- an MDT record — still "currently held" as far as the road is
            -- concerned.
            local held = (tonumber(facts.impound_held) or 0) > 0 or tonumber(vehicle.core_state) == 2
            local minCount = tonumber(cfg.minCount) or 2
            local criticalCount = tonumber(cfg.criticalCount) or 5

            -- A vehicle the records say is IN the lot has no business being
            -- scanned on the road, so that always flags regardless of count.
            if held or total >= minCount then
                local parts = {}
                if total > 0 then
                    parts[#parts + 1] = ('%d× impounded'):format(total)
                    local age = relativeAge(facts.impound_last)
                    if age then parts[#parts + 1] = 'last ' .. age end
                end
                if held then parts[#parts + 1] = 'currently held' end

                -- Escalates on its own: a repeat offender or a car that
                -- should be sitting in a lot outranks the configured base.
                local escalated = (total >= criticalCount or held) and 'critical' or nil
                addHit('impounds', 'Impound history',
                    #parts > 0 and table.concat(parts, ' · ') or nil,
                    'warning', escalated)
            end
        end
    else
        -- No record at all: a plate nobody registered is itself notable.
        addHit('unregistered', 'No vehicle record', nil, 'warning')
    end

    -- Active vehicle BOLO is keyed by plate, so it works even without a
    -- vehicle row (a BOLO can name a plate that was never registered).
    if (tonumber(facts.bolo_count) or 0) > 0 or (vehicle and isTruthy(vehicle.boloactive)) then
        addHit('bolo', 'Active BOLO', facts.bolo_notes, 'critical')
    end

    -- Insurance / registration come from optional third-party exports and
    -- fail open by design, so a missing provider never produces a false hit.
    if result.found and checkEnabled('insurance') and MdtResolveInsurance then
        local ok, byPlate = pcall(MdtResolveInsurance, { normalized })
        local entry = ok and byPlate and byPlate[normalized] or nil
        if entry and entry.status and entry.status ~= 'valid' then
            addHit('insurance', 'Insurance ' .. tostring(entry.status), entry.reason, 'warning')
        end
    end
    if result.found and checkEnabled('registration') and MdtResolveRegistration then
        local ok, byPlate = pcall(MdtResolveRegistration, { normalized })
        local entry = ok and byPlate and byPlate[normalized] or nil
        if entry and entry.registered == false then
            addHit('registration', 'Not registered', entry.reason, 'warning')
        end
    end

    -- Worst severity present drives the alert's priority.
    for _, hit in ipairs(result.hits) do
        if (SEVERITY_RANK[hit.severity] or 0) > (SEVERITY_RANK[result.severity] or 0) then
            result.severity = hit.severity
        end
    end

    return result
end

-- ── Caching + coalescing ─────────────────────────────────────────────────────

local cache = {}     -- plate -> { at = ms, result = table }
local inflight = {}  -- plate -> promise, one per plate being queried right now
local cacheCount = 0

--- Keep the cache bounded. Called when it grows past its cap rather than on
--- a timer: a scanner that never runs should never wake a thread, and one
--- that runs hard prunes itself as it goes.
---
--- Two stages, because expiry alone is not a guarantee: with enough officers
--- scanning enough traffic, every entry can still be fresh when the cap is
--- reached, and a TTL-only prune would free nothing while the table kept
--- growing. So if expiry does not get us under the cap, the oldest quarter is
--- evicted as well.
local function pruneCache(now, ttlMs, cap)
    for plate, entry in pairs(cache) do
        if (now - entry.at) >= ttlMs then
            cache[plate] = nil
            cacheCount = cacheCount - 1
        end
    end
    if cacheCount < cap then return end

    local ordered = {}
    for plate, entry in pairs(cache) do
        ordered[#ordered + 1] = { plate = plate, at = entry.at }
    end
    table.sort(ordered, function(a, b) return a.at < b.at end)
    local evict = math.max(1, math.floor(#ordered * 0.25))
    for i = 1, evict do
        cache[ordered[i].plate] = nil
        cacheCount = cacheCount - 1
    end
end

--- Cached, coalesced plate lookup.
--- Repeat scans inside the TTL never touch the database, and simultaneous
--- scans of one plate (two officers pointing a radar at the same car) share
--- a single query instead of racing.
---@param normalized string
---@return table
local function cachedLookup(normalized, candidates)
    local ttlMs = tuning('cacheSeconds', 60) * 1000
    local now = GetGameTimer()

    local entry = cache[normalized]
    if entry and (now - entry.at) < ttlMs then
        return entry.result
    end

    local pending = inflight[normalized]
    if pending then
        -- Someone is already asking; wait for their answer instead of adding
        -- a second identical query to the queue.
        return Citizen.Await(pending)
    end

    local p = promise.new()
    inflight[normalized] = p

    local ok, result = pcall(runPlateQueries, normalized, candidates)
    if not ok then
        ps.debug('platecheck: lookup failed for', normalized, tostring(result))
        result = { plate = normalized, found = false, hits = {} }
    end

    local cap = tuning('cacheMaxEntries', 2000)
    if cacheCount >= cap then
        pruneCache(now, ttlMs, cap)
    end
    if cache[normalized] == nil then cacheCount = cacheCount + 1 end
    cache[normalized] = { at = GetGameTimer(), result = result }

    inflight[normalized] = nil
    p:resolve(result)
    return result
end

--- Forget a plate's cached answer. Call after changing a BOLO, impound or
--- vehicle flag so scanners see the change immediately instead of after the
--- TTL.
---@param plate string|nil  nil clears the whole cache
function MdtInvalidatePlateCache(plate)
    local normalized = normalizePlate(plate)
    if not normalized then
        cache, cacheCount = {}, 0
        return
    end
    if cache[normalized] then
        cache[normalized] = nil
        cacheCount = cacheCount - 1
    end
end

exports('InvalidatePlateCache', MdtInvalidatePlateCache)

---@param plate string  Plate to look up (any casing/spacing)
---@param src number|nil Optional player context; when given, the same job
---                      check as PlateCheckAlert applies
---@return table result
--- result = {
---   plate, found, model, spawnName, owner, ownerCitizenid,
---   hits    = { { key, label, detail, severity }, ... },
---   severity = 'critical' | 'warning' | nil,
---   denied   = true when the player was not allowed to query,
--- }
--- Never throws: a missing table or disabled feature degrades to "no hit"
--- rather than failing the scan, because a radar must not break when an
--- optional MDT feature is switched off.
function MdtCheckPlate(plate, src)
    local normalized, candidates = plateCandidates(plate)
    if not normalized then
        return { plate = tostring(plate or ''), found = false, hits = {} }
    end

    -- `src` is optional so trusted server-side callers can look a plate up
    -- with no player context. Pass it and the same job check applies — worth
    -- doing from any scanner that acts on a player's behalf, so a compromised
    -- client resource cannot query the database through it.
    if src ~= nil and not mayRunPlateCheck(src) then
        return { plate = normalized, found = false, hits = {}, denied = true }
    end

    return cachedLookup(normalized, candidates)
end

exports('CheckPlate', MdtCheckPlate)

-- ── Alerting ─────────────────────────────────────────────────────────────────

-- src -> { [plate] = lastAlertMs }, and src -> { count, windowStart }
local alertedAt = {}
local alertBudget = {}

-- src -> per-officer plate-check preferences, mirrored from the MDT's
-- Settings tab. The alert decision happens here on the server, so the
-- preference has to travel: NUI -> client/backend/preferences.lua -> here.
-- Absent entries mean "never opened the MDT", which uses the defaults below.
local playerPrefs = {}

RegisterNetEvent('ps-mdt:server:setClientPrefs', function(data)
    local src = source
    if type(data) ~= 'table' then return end
    if not CheckAuth(src) then return end

    local stored = playerPrefs[src] or {}
    for _, name in ipairs({ 'plateCheckAlerts', 'plateCheckIgnoreImpounds', 'plateCheckCriticalOnly' }) do
        if type(data[name]) == 'boolean' then stored[name] = data[name] end
    end
    playerPrefs[src] = stored
end)

---@param src number
---@param name string
---@param default boolean
---@return boolean
local function playerPref(src, name, default)
    local stored = playerPrefs[src]
    if not stored or stored[name] == nil then return default end
    return stored[name]
end

AddEventHandler('playerDropped', function()
    local src = source
    alertedAt[src] = nil
    alertBudget[src] = nil
    playerPrefs[src] = nil
end)

--- Has this officer already been told about this plate recently?
---@param src number
---@param plate string
---@return boolean
local function onAlertCooldown(src, plate)
    local window = tuning('alertCooldown', 120) * 1000
    if window <= 0 then return false end
    local perPlate = alertedAt[src]
    if not perPlate then return false end
    local last = perPlate[plate]
    return last ~= nil and (GetGameTimer() - last) < window
end

--- Ceiling on alerts per officer per minute, so a street full of flagged
--- cars produces a readable trickle instead of a wall of cards.
---@param src number
---@return boolean allowed
local function takeAlertBudget(src)
    local maxPerMinute = tuning('maxAlertsPerMinute', 6)
    if maxPerMinute <= 0 then return true end
    local now = GetGameTimer()
    local bucket = alertBudget[src]
    if not bucket or (now - bucket.windowStart) >= 60000 then
        alertBudget[src] = { count = 1, windowStart = now }
        return true
    end
    if bucket.count >= maxPerMinute then return false end
    bucket.count = bucket.count + 1
    return true
end

---@param src number
---@param plate string
local function rememberAlert(src, plate)
    local perPlate = alertedAt[src]
    if not perPlate then perPlate = {} alertedAt[src] = perPlate end
    perPlate[plate] = GetGameTimer()

    -- Keep the per-officer table from growing across a long shift: anything
    -- past the cooldown can never suppress an alert again.
    local window = tuning('alertCooldown', 120) * 1000
    local now = GetGameTimer()
    local kept = 0
    for knownPlate, at in pairs(perPlate) do
        if (now - at) >= window then perPlate[knownPlate] = nil else kept = kept + 1 end
    end
end

---@param result table  Output of MdtCheckPlate
---@return string       One-line summary for the alert body
local function summarize(result)
    local parts = {}
    for _, hit in ipairs(result.hits) do
        parts[#parts + 1] = hit.detail and ('%s (%s)'):format(hit.label, hit.detail) or hit.label
    end
    return table.concat(parts, ' · ')
end

--- Run a plate check for a specific officer and, when there are hits, push a
--- targeted ps-dispatch alert to that officer only.
---
--- Safe to call in a tight scanning loop: the lookup is cached and coalesced,
--- and an officer is not alerted about the same plate twice inside
--- Config.PlateCheck.alertCooldown.
---@param src number       Server id of the scanning officer
---@param plate string
---@param coords table|nil Optional scan position, shown on the alert's map
---@return table result    The same table CheckPlate returns, plus `alerted`
function MdtPlateCheckAlert(src, plate, coords, plateIndex)
    if not mayRunPlateCheck(src) then
        return { plate = normalizePlate(plate) or tostring(plate or ''),
                 found = false, hits = {}, denied = true }
    end

    local normalized, candidates = plateCandidates(plate)
    if not normalized then
        return { plate = tostring(plate or ''), found = false, hits = {} }
    end

    local result = cachedLookup(normalized, candidates)
    local cfg = (Config.PlateCheck or {}).alert or {}

    -- Per-officer filters (MDT > Settings > Plate Checks). They only ever
    -- suppress an alert; the lookup itself and its result are unaffected, so
    -- a radar showing hits in its own UI still sees everything.
    local hitsForMe = result.hits
    if playerPref(src, 'plateCheckCriticalOnly', false) then
        local filtered = {}
        for _, hit in ipairs(hitsForMe) do
            if hit.severity == 'critical' then filtered[#filtered + 1] = hit end
        end
        hitsForMe = filtered
    end
    if playerPref(src, 'plateCheckIgnoreImpounds', false) then
        -- Drop impound history, then check what is LEFT: a car that is also
        -- stolen or wanted still alerts, only the "seen the lot a few times"
        -- case goes quiet.
        local filtered = {}
        for _, hit in ipairs(hitsForMe) do
            if hit.key ~= 'impounds' then filtered[#filtered + 1] = hit end
        end
        hitsForMe = filtered
    end

    local wantAlert = cfg.enabled ~= false
        and playerPref(src, 'plateCheckAlerts', true)
        and not (#hitsForMe == 0 and cfg.silentWhenClean ~= false)
        and not onAlertCooldown(src, normalized)

    if wantAlert and not takeAlertBudget(src) then
        wantAlert = false
    end

    -- Auditing follows the ALERT, not the scan. A continuous scanner passes
    -- hundreds of plates a minute; logging each one would bury the genuinely
    -- interesting queries and write more rows than the rest of the MDT
    -- combined. Set auditEveryScan = true if a complete query trail matters
    -- more than the write volume.
    -- The audit trail records the FULL result, not the officer's filtered
    -- view: what the database answered is the fact worth keeping.
    local root = Config.PlateCheck or {}
    if root.audit and ps.auditLog and (wantAlert or root.auditEveryScan) then
        -- auditLog performs a blocking insert; never make the scanner wait.
        CreateThread(function()
            ps.auditLog(src, 'plate_check', 'vehicle', normalized, {
                plate = normalized,
                hits = #result.hits,
                action_label = #result.hits > 0
                    and ('Plate check on %s — %s'):format(normalized, summarize(result))
                    or  ('Plate check on %s — no flags'):format(normalized),
            })
        end)
    end

    if not wantAlert then
        result.alerted = false
        return result
    end
    if GetResourceState('ps-dispatch') ~= 'started' then
        result.alerted = false
        return result
    end

    rememberAlert(src, normalized)

    -- Everything shown on the card reflects what this officer asked to see.
    local shown = { plate = result.plate, hits = hitsForMe }
    local critical = false
    for _, hit in ipairs(hitsForMe) do
        if hit.severity == 'critical' then critical = true break end
    end
    local ok, err = pcall(function()
        return exports['ps-dispatch']:SendTargetedAlert({ src }, {
            message = #hitsForMe > 0 and 'Plate Hit' or 'Plate Clear',
            code = cfg.code or '10-28',
            codeName = 'platecheck',
            icon = 'fas fa-magnifying-glass',
            priority = critical and 1 or 2,
            coords = coords,
            -- The plate renders in the alert's monospace plate style, and the
            -- model fills the vehicle strip — the same anatomy an officer
            -- already reads on every other alert.
            plate = normalized,
            plateIndex = plateIndex,
            vehicle = result.model,
            name = result.owner,
            information = #hitsForMe > 0 and summarize(shown) or 'No flags on this plate',
            -- Radio phrasing: a plate "comes back" clear or flagged. This is
            -- an answer to a query, not a job — so it gets its own footer
            -- instead of the assignment strip, and no respond prompt.
            footer = {
                icon = #hitsForMe > 0 and 'fas fa-triangle-exclamation' or 'fas fa-circle-check',
                text = #hitsForMe > 0
                    and ('Plate comes back flagged · %d'):format(#hitsForMe)
                    or 'Plate comes back clear',
                sub = 'MDT records',
                tone = critical and 'alert' or 'info',
            },
            alertTime = cfg.alertTime or 12,
        })
    end)
    if not ok then ps.debug('PlateCheckAlert: dispatch alert failed:', tostring(err)) end

    result.alerted = ok == true
    return result
end

exports('PlateCheckAlert', MdtPlateCheckAlert)

-- Manual check, handy for testing and for servers without a radar resource.
if Config.PlateCheck and Config.PlateCheck.command then
    lib.addCommand(Config.PlateCheck.command, {
        help = 'Run an MDT plate check',
        params = { { name = 'plate', type = 'string', help = 'Plate to check' } },
    }, function(source, args)
        MdtPlateCheckAlert(source, args.plate)
    end)
end