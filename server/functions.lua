function GetActiveUnits()
    return ps.getJobCount("police")
end

--- Normalise a free-text search query for consistent, predictable LIKE matching
--- across every search callback. Trims, collapses internal whitespace to single
--- spaces, lowercases, and escapes LIKE wildcards (% _ \) so user input is
--- treated literally (no accidental "match everything" / expensive scans).
---
--- Returns three values:
---   norm       - the cleaned, lowercased term (nil if the query is empty)
---   likePat    - '%term%' ready to bind to a LIKE placeholder
---   plateLike  - like likePat but with ALL spaces removed, so "AB 123",
---                "ab123" and "a b123" all match the same plate
---
--- Columns in this schema use a *_ci collation, so LIKE is already
--- case-insensitive; lowercasing keeps our own handling deterministic and lines
--- up with any LOWER()-wrapped columns.
---@param query any
---@return string|nil norm, string|nil likePat, string|nil plateLike
function NormalizeSearch(query)
    if query == nil then return nil end
    local s = tostring(query)
    s = s:gsub('%s+', ' '):gsub('^%s+', ''):gsub('%s+$', '')
    if s == '' then return nil end
    s = s:lower()
    -- escape LIKE wildcards so they match literally
    local escaped = s:gsub('([%%_\\])', '\\%1')
    local likePat = '%' .. escaped .. '%'
    local plateLike = '%' .. escaped:gsub(' ', '') .. '%'
    return s, likePat, plateLike
end

--- Returns a callsign only if it is safe to write to mdt_profiles for this
--- citizen. The callsign column has a UNIQUE index, so assigning a value that
--- another profile already owns throws a "Duplicate entry" error and aborts
--- whatever transaction is running (e.g. the login session upsert). This
--- normalises blank/sentinel values to nil and returns nil when the callsign is
--- already taken by a different citizen, so the caller keeps the existing value
--- (via COALESCE) or inserts NULL instead of crashing.
---@param callsign string|nil
---@param citizenid string|nil
---@return string|nil
function GetAssignableCallsign(callsign, citizenid)
    if callsign == 'NO CALLSIGN' or callsign == '' then callsign = nil end
    if not callsign then return nil end

    local taken = MySQL.scalar.await(
        'SELECT 1 FROM mdt_profiles WHERE callsign = ? AND citizenid != ? LIMIT 1',
        { callsign, citizenid or '' }
    )
    if taken then
        ps.warn(('Callsign "%s" is already in use - not assigning it to %s'):format(tostring(callsign), tostring(citizenid)))
        return nil
    end

    return callsign
end

--- Check if a job is a police/LEO job based on Config.PoliceJobs and Config.PoliceJobType
---@param jobName string|nil -- The job name to check (e.g. 'lspd', 'bcso')
---@param jobType string|nil -- The job type to check (e.g. 'leo')
---@return boolean
function IsPoliceJob(jobName, jobType)
    if jobType and Config and Config.PoliceJobType and tostring(jobType) == tostring(Config.PoliceJobType) then
        return true
    end
    if jobName and Config and Config.PoliceJobs then
        local check = tostring(jobName)
        for _, job in ipairs(Config.PoliceJobs) do
            if tostring(job) == check then
                return true
            end
        end
    end
    return false
end

--- Check if a job is a medical/EMS job based on Config.MedicalJobs and Config.MedicalJobType
---@param jobName string|nil
---@param jobType string|nil
---@return boolean
function IsEmsJob(jobName, jobType)
    if jobType and Config and Config.MedicalJobType and tostring(jobType) == tostring(Config.MedicalJobType) then
        return true
    end
    if jobName and Config and Config.MedicalJobs then
        local check = tostring(jobName)
        for _, job in ipairs(Config.MedicalJobs) do
            if tostring(job) == check then
                return true
            end
        end
    end
    return false
end

--- The MDT "domain" a job belongs to. Police and DOJ share the 'police' domain
--- (so their calendar / map data stays together); EMS is its own 'ems' domain.
---@param jobName string|nil
---@param jobType string|nil
---@return "police"|"ems"
function GetDomainForJob(jobName, jobType)
    if IsEmsJob(jobName, jobType) then return 'ems' end
    return 'police'
end

--- The MDT domain for an online player source.
---@param src number
---@return "police"|"ems"
--- Self-healing schema helper: add a column if it doesn't already exist.
-- ── Rate limiting ────────────────────────────────────────────────────────────
-- A client can fire NUI events as fast as it likes. Nothing stopped one from calling
-- createReport or createBolo in a tight loop and flooding the database — not an exploit
-- in the sense of reading data it shouldn't, but one bad or malicious client shouldn't
-- be able to bury the server in writes. This is a lightweight sliding-window limiter:
-- the caller records an action, and it's rejected if it happens too often too quickly.

local rlBuckets = {}   -- key -> { timestamps }

--- Is this action allowed right now?
---
--- Keyed by source AND action, so a burst of one kind of write doesn't lock the player
--- out of everything else. Returns false when the limit is exceeded; the caller decides
--- what to tell the user.
---@param src number
---@param action string   -- a stable name, e.g. 'createReport'
---@param max number      -- how many are allowed within the window
---@param windowMs number -- the window length in milliseconds
---@return boolean allowed
function RateLimit(src, action, max, windowMs)
    if not src or src <= 0 then return true end  -- server-invoked, not a player
    max = max or 5
    windowMs = windowMs or 10000

    local key = tostring(src) .. ':' .. tostring(action)
    local now = GetGameTimer()
    local bucket = rlBuckets[key]

    if not bucket then
        bucket = {}
        rlBuckets[key] = bucket
    end

    -- Drop anything that's aged out of the window.
    local cutoff = now - windowMs
    local kept = {}
    for _, t in ipairs(bucket) do
        if t > cutoff then kept[#kept + 1] = t end
    end
    rlBuckets[key] = kept

    if #kept >= max then return false end

    kept[#kept + 1] = now
    return true
end

--- Convenience wrapper that reads the cap from Config.RateLimits by action name.
--- Returns false (blocked) only when limiting is enabled AND the action has a config
--- entry AND the caller is over the cap — so an unlisted action is never accidentally
--- throttled.
---@param src number
---@param action string
---@return boolean allowed
function RateLimitAction(src, action)
    local cfg = Config and Config.RateLimits
    if not cfg or cfg.Enabled ~= true then return true end
    local rule = cfg[action]
    if not rule then return true end
    return RateLimit(src, action, rule.max, rule.windowMs)
end

--- Clear a disconnected player's buckets so the table doesn't grow without bound.
AddEventHandler('playerDropped', function()
    local src = source
    if not src then return end
    local prefix = tostring(src) .. ':'
    for key in pairs(rlBuckets) do
        if key:sub(1, #prefix) == prefix then rlBuckets[key] = nil end
    end
end)

-- ── Department banking ───────────────────────────────────────────────────────
-- Money taken from a citizen used to vanish. It should end up with the department that
-- collected it. Every banking resource disagrees about how to be paid, so this resolves
-- the account and then does whatever the config says.

local function bankingCfg()
    return (Config and Config.DepartmentBanking) or {}
end

--- Which account does this job pay into? The job name, unless the config overrides it.
---@param jobName string|nil
---@return string|nil
function DepartmentAccount(jobName)
    local cfg = bankingCfg()
    if jobName and jobName ~= '' then
        local mapped = (cfg.Accounts or {})[jobName]
        if mapped and mapped ~= '' then return mapped end
        return jobName
    end
    -- No job on the record (an impound from before we started storing it, say).
    local fb = cfg.Fallback
    return (fb and fb ~= '') and fb or nil
end

--- Build the argument list for a call, substituting the placeholders.
local function buildArgs(spec, account, amount, reason)
    local out = {}
    for i, key in ipairs(spec or {}) do
        if key == 'account' then out[i] = account
        elseif key == 'amount' then out[i] = amount
        elseif key == 'reason' then out[i] = reason
        else out[i] = key end
    end
    return out
end

--- Pay money into a department's account.
---
--- Deliberately never throws and never blocks the caller: the citizen has already been
--- charged by the time this runs, and a misconfigured banking resource must not undo a
--- payment that went through. A failure is loud in the console, not in the player's face.
---@param jobName string|nil  -- the department that collected (e.g. 'police')
---@param amount number
---@param reason string
---@return boolean deposited
function DepositToDepartment(jobName, amount, reason)
    local cfg = bankingCfg()
    if cfg.Enabled ~= true then return false end

    local method = cfg.Method or 'none'
    if method == 'none' then return false end

    amount = tonumber(amount) or 0
    if amount <= 0 then return false end

    local account = DepartmentAccount(jobName)
    if not account then
        ps.warn(('[banking] No account for job "%s" and no Fallback set — $%d not deposited.')
            :format(tostring(jobName), amount))
        return false
    end

    reason = reason or 'ps-mdt'

    local ok, err = pcall(function()
        if method == 'custom' then
            local fn = cfg.Custom
            if type(fn) ~= 'function' then error('Method is "custom" but Custom is not a function') end
            return fn(account, amount, reason) == true
        end

        if method == 'event' then
            local e = cfg.Event or {}
            if not e.name or e.name == '' then error('Method is "event" but Event.name is empty') end
            TriggerEvent(e.name, table.unpack(buildArgs(e.args, account, amount, reason)))
            -- An event gives us no answer, so we take it on trust.
            return true
        end

        -- export
        local e = cfg.Export or {}
        if not e.resource or not e.method then error('Method is "export" but Export.resource/method is empty') end

        local res = exports[e.resource]
        if not res then error(('resource "%s" is not running'):format(tostring(e.resource))) end

        local fn = res[e.method]
        if type(fn) ~= 'function' then
            error(('export %s:%s does not exist'):format(tostring(e.resource), tostring(e.method)))
        end

        fn(res, table.unpack(buildArgs(e.args, account, amount, reason)))
        return true
    end)

    if not ok then
        -- Loud, because money that should have arrived hasn't — but the citizen's payment
        -- stands, so this is a bookkeeping problem, not a transaction to roll back.
        print(('[ps-mdt] [banking] Failed to deposit $%d into "%s": %s')
            :format(amount, tostring(account), tostring(err)))
        return false
    end

    if Config and Config.Debug then
        print(('[ps-mdt] [banking] Deposited $%d into "%s" (%s)'):format(amount, account, reason))
    end
    return true
end

-- ── Display names ────────────────────────────────────────────────────────────
-- Spawn names ("nero", "banshee2") are what the game calls a car; nobody else does.
-- Item names ("WEAPON_HEAVYPISTOL") are the same problem. These resolve both to what
-- a person would actually say, and live here so every screen agrees on the answer.

local sharedCore
local function core()
    if sharedCore then return sharedCore end
    local ok, c = pcall(function() return exports['qb-core']:GetCoreObject() end)
    if ok and c then sharedCore = c return sharedCore end
    local okQbx, qbx = pcall(function() return exports['qbx_core']:GetCoreObject() end)
    if okQbx and qbx then sharedCore = qbx return sharedCore end
    return nil
end

--- "nero" → "Truffade Nero". Falls back to the spawn name, which is still better than
--- an empty cell.
---@param model string
---@return string
function VehicleDisplayName(model)
    if not model or model == '' then return 'Unknown Vehicle' end

    local c = core()
    local data = c and c.Shared and c.Shared.Vehicles and c.Shared.Vehicles[model]
    if not data then return model end

    local name  = data.name or model
    local brand = data.brand

    -- Some shared files already fold the brand into the name. Don't say it twice.
    if brand and brand ~= '' and not name:lower():find(brand:lower(), 1, true) then
        return brand .. ' ' .. name
    end
    return name
end

--- Spawn names whose display name matches a query.
---
--- The database only stores "nero", so a search for "Truffade" would find nothing even
--- though that's what the UI shows. The shared vehicle table is already in memory, so
--- scanning it is cheap — and it lets the officer search for the name they can see.
---@param query string
---@param limit number|nil
---@return string[] models
function VehicleModelsMatching(query, limit)
    local out = {}
    if not query or query == '' then return out end

    local c = core()
    local shared = c and c.Shared and c.Shared.Vehicles
    if not shared then return out end

    local needle = query:lower()
    limit = limit or 25

    for model, data in pairs(shared) do
        local brand = (data.brand or ''):lower()
        local name  = (data.name or ''):lower()
        if brand:find(needle, 1, true) or name:find(needle, 1, true) then
            out[#out + 1] = model
            if #out >= limit then break end
        end
    end

    return out
end

--- "WEAPON_HEAVYPISTOL" → "Heavy Pistol".
---@param weaponModel string
---@return string
function WeaponLabel(weaponModel)
    if not weaponModel or weaponModel == '' then return 'Unknown Weapon' end

    local c = core()
    if not (c and c.Shared) then return weaponModel end

    -- Weapons are keyed by hash; items by lowercase name. Different servers register
    -- them in different places, so try both before giving up.
    local byHash = c.Shared.Weapons and c.Shared.Weapons[GetHashKey(weaponModel)]
    if byHash and byHash.label and byHash.label ~= '' then return byHash.label end

    local byItem = c.Shared.Items and c.Shared.Items[weaponModel:lower()]
    if byItem and byItem.label and byItem.label ~= '' then return byItem.label end

    return weaponModel
end

--- The inventory image for a weapon, matching what the Weapons tab already uses.
---@param weaponModel string
---@return string|nil
function WeaponImage(weaponModel)
    if not weaponModel or weaponModel == '' then return nil end
    local path = Config and Config.WeaponImagePath
    if not path or path == '' then return nil end
    return path .. weaponModel:upper() .. '.png'
end

--- Same idea as EnsureColumn, for indexes. Adding one on a table that has grown large
--- can take a moment, which is exactly why it's worth doing before it grows further.
---@param tableName string
---@param indexName string
---@param columns string -- e.g. "`created_at`"
---@return boolean added
function EnsureIndex(tableName, indexName, columns)
    local exists = MySQL.single.await([[
        SELECT 1 AS x FROM information_schema.STATISTICS
        WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ? AND INDEX_NAME = ?
    ]], { tableName, indexName })
    if exists then return false end
    local ok = pcall(MySQL.query.await,
        ('ALTER TABLE `%s` ADD INDEX `%s` (%s)'):format(tableName, indexName, columns))
    if ok then
        print(('[ps-mdt] added index %s on %s'):format(indexName, tableName))
    end
    return ok
end

--- Lets backends introduce a new column (e.g. a domain marker) without shipping
--- a manual migration. No-op if the column is already present.
---@param tableName string
---@param columnName string
---@param definition string -- full column definition, e.g. "`job_type` varchar(10) NOT NULL DEFAULT 'police'"
---@return boolean added
function EnsureColumn(tableName, columnName, definition)
    local exists = MySQL.single.await([[
        SELECT 1 AS x FROM information_schema.COLUMNS
        WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ? AND COLUMN_NAME = ?
    ]], { tableName, columnName })
    if exists then return false end
    local ok = pcall(MySQL.query.await, ('ALTER TABLE `%s` ADD COLUMN %s'):format(tableName, definition))
    if ok and Config and Config.Debug then
        print(('[ps-mdt] added column %s.%s'):format(tableName, columnName))
    end
    return ok
end

function GetMdtDomain(src)
    local jobName = ps.getJobName and ps.getJobName(src) or nil
    local jobType = ps.getJobType and ps.getJobType(src) or nil
    return GetDomainForJob(jobName, jobType)
end


--- Ensure an MDT profile exists for a citizen. Resolves name from online player or DB if offline.
---@param citizenid string -- The citizen ID to ensure a profile for
---@return boolean -- true if profile exists or was created, false on failure
function EnsureProfileExists(citizenid)
    if not citizenid then return false end

    local exists = MySQL.scalar.await('SELECT COUNT(*) FROM mdt_profiles WHERE citizenid = ?', { citizenid })
    if exists and exists > 0 then
        return true
    end

    -- Try online player first
    local playerData = ps.getPlayerByIdentifier(citizenid)
    if playerData then
        playerData = playerData.PlayerData
        local charinfo = playerData.charinfo
        local fullname = charinfo.firstname .. ' ' .. charinfo.lastname
        local callsign = playerData.metadata and playerData.metadata.callsign or nil
        callsign = GetAssignableCallsign(callsign, citizenid)

        local success = MySQL.insert.await([[
            INSERT INTO mdt_profiles (citizenid, fullname, callsign)
            VALUES(?, ?, ?)
        ]], { citizenid, fullname, callsign })

        if success then
            ps.debug('Auto-created MDT profile for: ' .. citizenid)
            return true
        end
        ps.warn('Failed to create MDT profile for: ' .. citizenid)
        return false
    end

    -- Fallback: resolve from players table (offline player)
    local row = MySQL.single.await('SELECT charinfo, metadata FROM players WHERE citizenid = ? LIMIT 1', { citizenid })
    if not row then
        ps.warn('No player data found for citizenid: ' .. citizenid)
        return false
    end

    local charinfo = row.charinfo and json.decode(row.charinfo) or {}
    local metadata = row.metadata and json.decode(row.metadata) or {}
    local fullname = ((charinfo.firstname or '') .. ' ' .. (charinfo.lastname or '')):gsub('^%s+', ''):gsub('%s+$', '')
    local callsign = metadata.callsign
    callsign = GetAssignableCallsign(callsign, citizenid)

    local success = MySQL.insert.await([[
        INSERT INTO mdt_profiles (citizenid, fullname, callsign)
        VALUES(?, ?, ?)
    ]], { citizenid, fullname ~= '' and fullname or 'Unknown', callsign })

    if success then
        ps.debug('Auto-created MDT profile for: ' .. citizenid)
        return true
    end
    ps.warn('Failed to create MDT profile for: ' .. citizenid)
    return false
end

function EnsureProfileData(citizenid, fullname, callsign, badgeNumber, rank, department)
    if not citizenid then
        return nil
    end

    -- Sanitize callsign and skip it if another profile already owns it
    -- (UNIQUE index would otherwise throw and abort the caller's transaction).
    callsign = GetAssignableCallsign(callsign, citizenid)

    local profile = MySQL.single.await('SELECT id FROM mdt_profiles WHERE citizenid = ?', { citizenid })
    if profile and profile.id then
        -- Try the full update; if it still trips the callsign UNIQUE index for
        -- any reason (e.g. a race), retry once without touching the callsign so
        -- the profile/session is never lost over a callsign clash.
        local ok = pcall(MySQL.update.await, [[UPDATE mdt_profiles
            SET fullname = COALESCE(?, fullname),
                callsign = COALESCE(?, callsign),
                badge_number = COALESCE(?, badge_number),
                rank = COALESCE(?, rank),
                department = COALESCE(?, department)
            WHERE citizenid = ?
        ]], { fullname, callsign, badgeNumber, rank, department, citizenid })

        if not ok then
            ps.warn(('EnsureProfileData: update failed for %s, retrying without callsign'):format(tostring(citizenid)))
            pcall(MySQL.update.await, [[UPDATE mdt_profiles
                SET fullname = COALESCE(?, fullname),
                    badge_number = COALESCE(?, badge_number),
                    rank = COALESCE(?, rank),
                    department = COALESCE(?, department)
                WHERE citizenid = ?
            ]], { fullname, badgeNumber, rank, department, citizenid })
        end

        return profile.id
    end

    local okInsert, result = pcall(MySQL.insert.await, [[INSERT INTO mdt_profiles
        (citizenid, fullname, callsign, badge_number, rank, department)
        VALUES (?, ?, ?, ?, ?, ?)
    ]], { citizenid, fullname or 'Unknown', callsign, badgeNumber, rank, department })

    if not okInsert then
        -- Insert failed (most likely the callsign clash). Retry without callsign.
        ps.warn(('EnsureProfileData: insert failed for %s, retrying without callsign'):format(tostring(citizenid)))
        okInsert, result = pcall(MySQL.insert.await, [[INSERT INTO mdt_profiles
            (citizenid, fullname, badge_number, rank, department)
            VALUES (?, ?, ?, ?, ?)
        ]], { citizenid, fullname or 'Unknown', badgeNumber, rank, department })
    end

    if not okInsert then
        ps.error(('EnsureProfileData: could not create profile for %s: %s'):format(tostring(citizenid), tostring(result)))
        return nil
    end

    return result
end

-- Returns the owner of a vehicle based on its license plate.
---@param plate string -- The license plate of the vehicle to check
---@return string -- The name of the vehicle owner or "Unknown Owner" if not found
function GetVehicleOwner(plate)
    if not plate then
        return "Unknown Owner"
    end

    -- Sanitise plate input. Trim the padding, keep spaces inside the plate.
    plate = NormalizePlate(plate)
    if not plate then return nil end
    ps.debug('Fetching vehicle owner for plate: ' .. plate)

    -- Fetch the owner
    local result = MySQL.scalar.await('SELECT citizenid FROM player_vehicles WHERE plate = ? LIMIT 1', { plate })
    ps.debug('Vehicle owner result: ' .. tostring(result))

    if result then
        -- If a result is found, get the player's name
        local playerName = ps.getPlayerNameByIdentifier(result)
        ps.debug('Vehicle owner name: ' .. tostring(playerName))
        if playerName and playerName ~= 'Unknown Person' then
            return playerName
        end
    end

    -- If no owner or player name is found, return "Unknown Owner"
    ps.debug('No owner found for plate: ' .. plate)
    return "Unknown Owner"
end

function GetBoloStatus(plate)
    if not plate then return false, "", "" end
    plate = string.gsub(plate, "%s+", "")
    plate = string.upper(plate)

    local result = MySQL.single.await([[
        SELECT id, subject_name, notes
        FROM mdt_bolos
        WHERE type = 'vehicle'
          AND status = 'active'
          AND UPPER(REPLACE(subject_id, ' ', '')) = ?
        LIMIT 1
    ]], { plate })

    if result then
        return true, result.subject_name or result.notes or "Active BOLO", tostring(result.id)
    end
    return false, "", ""
end

-- Returns the warrant status for a given report ID.
---@param reportId number -- The ID of the report to check for a warrant
---@return boolean, string -- Returns true if a warrant is active, false otherwise, along with a status message
function GetWarrantStatusByReport(reportId)
    if not reportId then
        return false, "No report ID provided"
    end

    local reportIdNumber = tonumber(reportId)
    if not reportIdNumber then
        return false, "Invalid report ID type"
    end

    local warrantRow = MySQL.single.await([[
        SELECT reportid, expirydate
        FROM mdt_reports_warrants
        WHERE reportid = ?
          AND expirydate >= NOW()
        LIMIT 1
    ]], { reportIdNumber })

    if not warrantRow then
        return false, "No active warrant"
    end

    return true, "Warrant is active"
end

-- Returns the warrant status for a vehicle plate (used by plate reader).
---@param plate string -- The vehicle plate to check
---@return boolean, string, string -- Returns warrant found, owner name, report ID
function GetWarrantStatus(plate)
    if not plate then return false, "", "" end
    plate = string.gsub(plate, "%s+", "")
    plate = string.upper(plate)

    local ownerCid = MySQL.scalar.await('SELECT citizenid FROM player_vehicles WHERE UPPER(REPLACE(plate, \' \', \'\')) = ? LIMIT 1', { plate })
    if not ownerCid then return false, "", "" end

    local ownerName = ps.getPlayerNameByIdentifier(ownerCid) or "Unknown"

    local warrantRow = MySQL.single.await([[
        SELECT reportid
        FROM mdt_reports_warrants
        WHERE citizenid = ?
          AND expirydate >= NOW()
        LIMIT 1
    ]], { ownerCid })

    if warrantRow then
        return true, ownerName, tostring(warrantRow.reportid)
    end
    return false, "", ""
end

-- Count charges for a citizen from the v3 normalized schema
function countCharges(cid)
    local rows = MySQL.query.await([[
        SELECT pc.charge_class, SUM(rc.count) AS total
        FROM mdt_reports_charges rc
        JOIN mdt_penal_codes pc ON rc.charge = pc.label
        WHERE rc.citizenid = ?
        GROUP BY pc.charge_class
    ]], { cid })

    local chargeCounts = { Felony = 0, Misdemeanor = 0, Infraction = 0 }
    if rows then
        for _, row in ipairs(rows) do
            local class = row.charge_class
            if class == 'felony' then
                chargeCounts.Felony = tonumber(row.total) or 0
            elseif class == 'misdemeanor' then
                chargeCounts.Misdemeanor = tonumber(row.total) or 0
            elseif class == 'infraction' then
                chargeCounts.Infraction = tonumber(row.total) or 0
            end
        end
    end

    local chargeDetails = MySQL.query.await([[
        SELECT rc.reportid, rc.charge, rc.count, rc.time, rc.fine, pc.charge_class
        FROM mdt_reports_charges rc
        JOIN mdt_penal_codes pc ON rc.charge = pc.label
        WHERE rc.citizenid = ?
        ORDER BY rc.reportid DESC
    ]], { cid })

    return { charges = chargeDetails or {}, count = chargeCounts }
end

-- Get reports where a citizen is involved (replaces old getIncidents that used mdt_incidents)
function getIncidents(cid)
    if not cid then return {} end

    local reports = MySQL.query.await([[
        SELECT r.id, r.title, r.type, r.datecreated
        FROM mdt_reports r
        INNER JOIN mdt_reports_involved ri ON r.id = ri.reportid
        WHERE ri.citizenid = ?
        ORDER BY r.datecreated DESC
        LIMIT 20
    ]], { cid })

    return reports or {}
end

-- Get citizen list with charge counts and weapon counts (batch queries, no N+1)
function getCitizens(source)
    if ps.getJobType(source) ~= "leo" then
        return {}
    end

    local citizens = MySQL.query.await([[
        SELECT p.citizenid,
               JSON_UNQUOTE(JSON_EXTRACT(p.charinfo, '$.firstname')) AS firstname,
               JSON_UNQUOTE(JSON_EXTRACT(p.charinfo, '$.lastname')) AS lastname
        FROM players p
        LIMIT 50
    ]], {})

    if not citizens or #citizens == 0 then return {} end

    local result = {}
    for i = 1, #citizens do
        local cid = citizens[i].citizenid
        local weaponCount = MySQL.scalar.await('SELECT COUNT(*) FROM mdt_weapons WHERE owner = ?', { cid }) or 0
        result[#result + 1] = {
            name = (citizens[i].firstname or '') .. ' ' .. (citizens[i].lastname or ''),
            identifier = cid,
            convictions = countCharges(cid),
            incidents = getIncidents(cid),
            weapons = {},
            weaponCount = tonumber(weaponCount) or 0,
        }
    end
    return result
end

ps.registerCallback('ps-mdt:hasProfile', function(source)
    local src = source
    assert(src, 'Player ID cannot be nil')
    local citizenId = ps.getIdentifier(src)
    if not citizenId then
        ps.warn('No citizen ID found for source: ' .. tostring(src))
        return false
    end

    return EnsureProfileExists(citizenId)
end)
-- ---------------------------------------------------------------------------
-- Phone number resolution (config-based, export-driven)
-- ---------------------------------------------------------------------------
-- Resolve a citizen's phone number through the configured phone resource so the
-- MDT shows the correct number even when it isn't stored in charinfo.phone
-- (lb-phone, gksphone, yseries, …). `fallback` is the charinfo.phone value; it is
-- returned when the phone resource yields nothing and Config.Phone.UseCharinfoFallback
-- is not disabled. Returns nil only when neither source produces a number.
function GetCitizenPhoneNumber(citizenid, fallback)
    -- Delegates to the phone abstraction (server/backend/phone.lua), which
    -- performs whichever call shape Config.Phone describes. Kept as a global
    -- because half the MDT already calls it by this name.
    if PhoneNumberFor then return PhoneNumberFor(citizenid, fallback) end

    -- phone.lua not loaded (or load order changed): charinfo is still better
    -- than nothing.
    local cfg = (Config and Config.Phone) or {}
    if cfg.UseCharinfoFallback ~= false and fallback ~= nil and tostring(fallback) ~= '' then
        return tostring(fallback)
    end
    return nil
end

-- Convenience export so other resources can reuse the same resolution.
-- ── Callsigns ────────────────────────────────────────────────────────────────
-- The range an officer may pick from comes from their job, falling back to their job
-- type. There is no global default on purpose: an unconfigured job is a mistake, and
-- silently issuing numbers from some arbitrary range would hide it. Every path below
-- returns an explanation instead.

--- Flatten a Reserved/Blocked list into a plain [number] = reason map.
---
--- ONLY the list form is accepted:
---   { { n = 7, why = '…' }, { from = 90, to = 99, why = '…' } }
---
--- The obvious-looking [7] = '…' map form is rejected on purpose, because mixing it
--- with a range is a silent data-loss trap:
---
---   { [1] = 'Chief of Police', { from = 2, to = 5, why = 'Command staff' } }
---
--- A keyless entry in Lua IS index 1, so the range overwrites 'Chief of Police' while
--- the config is being parsed. By the time any code here runs, the string no longer
--- exists — it cannot be detected, only prevented. So the shape that allows it is not
--- accepted at all, and the error says exactly what to write instead.
--- @return table map, string|nil problem
local function expandCallsignRules(rules, label)
    local out = {}
    if type(rules) ~= 'table' then return out, nil end

    for key, value in pairs(rules) do
        if type(value) == 'table' then
            if value.n ~= nil then
                local n = tonumber(value.n)
                if not n then
                    return out, ('a %s entry has a non-numeric `n`'):format(label)
                end
                out[n] = value.why or label
            else
                local from, to = tonumber(value.from), tonumber(value.to)
                if not from or not to then
                    return out, ('a %s entry needs either `n`, or `from` and `to`'):format(label)
                end
                if to < from then
                    return out, ('a %s range has `to` below `from`'):format(label)
                end
                for n = from, to do
                    out[n] = value.why or label
                end
            end
        else
            return out, (
                '%s uses the old [%s] = \'…\' form. Write it as { n = %s, why = \'…\' } — '
                .. 'the bracket form silently loses entries when a range is added next to it, '
                .. 'because a keyless range takes index 1 and overwrites [1]'
            ):format(label, tostring(key), tostring(key))
        end
    end

    return out, nil
end

--- Resolve the callsign block for a job.
--- @return table|nil cfg, string|nil problem
function CallsignConfigFor(jobName, jobType)
    local root = (Config and Config.Callsigns) or {}

    -- A job block replaces the job-type block outright; it is not merged into it.
    local cfg = jobName and (root.Jobs or {})[jobName] or nil
    local source = cfg and ('job "' .. tostring(jobName) .. '"') or nil

    if not cfg then
        cfg = jobType and (root.JobTypes or {})[jobType] or nil
        source = cfg and ('job type "' .. tostring(jobType) .. '"') or nil
    end

    if not cfg then
        return nil, ('No callsign range is configured for job "%s" (type "%s"). Add it to Config.Callsigns.')
            :format(tostring(jobName or '?'), tostring(jobType or '?'))
    end

    local minN, maxN = tonumber(cfg.Min), tonumber(cfg.Max)
    if not minN or not maxN then
        return nil, ('The callsign block for %s is missing Min or Max.'):format(source)
    end
    if maxN < minN then
        return nil, ('The callsign block for %s has Max below Min.'):format(source)
    end

    local reserved, rErr = expandCallsignRules(cfg.Reserved, 'Reserved')
    if rErr then
        return nil, ('The callsign block for %s is invalid: %s'):format(source, rErr)
    end

    local blocked, bErr = expandCallsignRules(cfg.Blocked, 'Blocked')
    if bErr then
        return nil, ('The callsign block for %s is invalid: %s'):format(source, bErr)
    end

    -- Blocked wins over Reserved: "nobody" is a stronger statement than "somebody with
    -- the permission". Listing a number in both is a mistake worth pointing at.
    for n in pairs(blocked) do
        if reserved[n] then
            return nil, ('The callsign block for %s lists %d as both Reserved and Blocked.')
                :format(source, n)
        end
    end

    return {
        Min      = minN,
        Max      = maxN,
        Pad      = tonumber(cfg.Pad) or 0,
        Prefix   = cfg.Prefix or '',
        PageSize = tonumber(cfg.PageSize) or 20,
        Reserved = reserved,
        Blocked  = blocked,
        Source   = source,
    }, nil
end

--- The block that applies to a connected player.
--- @return table|nil cfg, string|nil problem
function CallsignConfigForPlayer(src)
    local jobName = ps.getJobName and ps.getJobName(src) or nil
    local jobType = ps.getJobType and ps.getJobType(src) or nil
    return CallsignConfigFor(jobName, jobType)
end

--- Render a number the way its block says it should look: 7 → "L-007".
function FormatCallsign(n, cfg)
    if not cfg then return tostring(n) end
    local pad = tonumber(cfg.Pad) or 0
    local body = pad > 0 and ('%0' .. pad .. 'd'):format(n) or tostring(n)
    return (cfg.Prefix or '') .. body
end

--- May this officer hand out callsigns marked reserved?
--- Separate from roster_manage_officers on purpose: an FTO can be trusted to give a
--- recruit a number without also being able to hand out the Chief's.
function CanAssignReservedCallsign(src)
    return CheckPermission(src, 'roster_callsign_reserved') == true
end

--- Is this a callsign the given citizen is allowed to take?
--- The picker only offers valid boxes, but a client can send anything.
--- @return boolean ok, string|nil message, string|nil reservedReason
function ValidateCallsignPick(src, callsign, citizenid)
    callsign = tostring(callsign or '')
    if callsign == '' then return false, 'Missing callsign' end

    local cfg, problem = CallsignConfigForPlayer(src)
    if not cfg then return false, problem end

    local matched
    for n = cfg.Min, cfg.Max do
        if FormatCallsign(n, cfg) == callsign then matched = n break end
    end
    if not matched then
        return false, ('%s is outside the range configured for %s'):format(callsign, cfg.Source)
    end

    -- Blocked first, and it is absolute. No permission unlocks it — the config has
    -- said this number is not to be issued, and that isn't a matter of rank.
    local blockedWhy = (cfg.Blocked or {})[matched]
    if blockedWhy then
        return false, ('%s is blocked (%s) and cannot be assigned to anyone')
            :format(callsign, tostring(blockedWhy))
    end

    -- Reserved callsigns are not off-limits to everyone — they're off-limits to anyone
    -- without the permission for them.
    local why = (cfg.Reserved or {})[matched]
    if why and not CanAssignReservedCallsign(src) then
        return false, ('%s is reserved (%s) and you are not authorised to assign it')
            :format(callsign, tostring(why))
    end

    -- Held by somebody else?
    --
    -- A callsign lives in two places: mdt_profiles.callsign and the player's metadata.
    -- Checking only the profile table left a hole — a callsign set outside the MDT (or
    -- on a player whose profile row was never filled in) looked free here while the
    -- officer was already using it in game. Both are checked, and the holder is named
    -- rather than left as a mystery.
    local holder = CallsignHolder(callsign, citizenid)
    if holder then
        return false, ('%s is already held by %s'):format(callsign, holder)
    end

    return true, nil, why
end

--- Normalise a number plate for lookups and storage.
---
--- GetVehicleNumberPlateText always returns 8 characters, PADDED WITH TRAILING SPACES.
--- Code around the resource dealt with that by stripping every space — which also
--- destroys the spaces INSIDE a plate, so "LS 12345" became "LS12345" and matched
--- nothing in player_vehicles. Trim the padding; keep the plate.
---
--- Trailing spaces need no special handling in SQL either: the plate columns use a
--- PAD SPACE collation, so 'ABC123' = 'ABC123  ' already compares equal.
--- @param plate string|nil
--- @return string|nil  the trimmed, uppercased plate, or nil if there's nothing left
function NormalizePlate(plate)
    if type(plate) ~= 'string' then return nil end
    plate = plate:upper():gsub('^%s+', ''):gsub('%s+$', '')
    return plate ~= '' and plate or nil
end

--- SetMetaData only updates the player in memory; the `players.metadata` column is
--- rewritten on the next autosave or logout. Anything that reads that column in the
--- meantime — including the callsign uniqueness check — sees the OLD value. Writing the
--- live metadata straight back keeps the two in step. The snapshot is identical to
--- what's in memory, so the next autosave rewrites the same value and nothing is lost.
function PersistLiveMetadata(Player, citizenid)
    if not (Player and Player.PlayerData and Player.PlayerData.metadata and citizenid) then return end
    local ok, encoded = pcall(json.encode, Player.PlayerData.metadata)
    if ok and encoded then
        MySQL.update.await('UPDATE players SET metadata = ? WHERE citizenid = ?', { encoded, citizenid })
    end
end

--- Take a callsign off a citizen, in both stores, in an order that can't undo itself.
---
--- The order is the whole point. Clearing the DB first and the player second means
--- PersistLiveMetadata writes the in-memory metadata straight back over the DB — and
--- since most QB/QBX builds guard SetMetaData with `if not val then return end`, passing
--- nil is a no-op and the OLD callsign is what gets written back. Releasing a callsign
--- looked like it half-worked and needed doing twice.
---
--- So: clear the player's memory FIRST, using an empty string (no framework guards
--- against that), persist it, and only then clean the DB. Nothing left can rewrite it.
function ClearCallsign(citizenid)
    if not citizenid then return end

    local ok, QBCore = pcall(function() return exports['qb-core']:GetCoreObject() end)
    if ok and QBCore then
        local Player = QBCore.Functions.GetPlayerByCitizenId(citizenid)
        if Player then
            Player.Functions.SetMetaData('callsign', '')
            PersistLiveMetadata(Player, citizenid)
            TriggerClientEvent(GetCurrentResourceName() .. ':client:updateCallsign',
                Player.PlayerData.source, '')
        end
    end

    MySQL.update.await('UPDATE mdt_profiles SET callsign = NULL WHERE citizenid = ?', { citizenid })
    MySQL.update.await(
        "UPDATE players SET metadata = JSON_SET(metadata, '$.callsign', '') WHERE citizenid = ?",
        { citizenid })
end

--- Who holds this callsign, other than `exceptCitizenid`?
--- @return string|nil holderName  nil when nobody holds it
function CallsignHolder(callsign, exceptCitizenid)
    exceptCitizenid = exceptCitizenid or ''

    local row = MySQL.single.await([[
        SELECT fullname, citizenid
        FROM mdt_profiles
        WHERE callsign = ? AND citizenid != ?
        LIMIT 1
    ]], { callsign, exceptCitizenid })
    if row then
        return (row.fullname and row.fullname ~= '' and row.fullname) or row.citizenid
    end

    -- Second home: the framework's own metadata. Worth checking, because a callsign set
    -- outside the MDT never reaches mdt_profiles.
    --
    -- But only for officers the profile table says nothing about. If their profile
    -- already names a DIFFERENT callsign, the metadata value is stale — and treating a
    -- stale value as a live claim would lock that number away from everybody else.
    local meta = MySQL.single.await([[
        SELECT p.citizenid,
               CONCAT(
                   JSON_UNQUOTE(JSON_EXTRACT(p.charinfo, '$.firstname')), ' ',
                   JSON_UNQUOTE(JSON_EXTRACT(p.charinfo, '$.lastname'))
               ) AS fullname
        FROM players p
        LEFT JOIN mdt_profiles pr ON pr.citizenid = p.citizenid COLLATE utf8mb4_general_ci COLLATE utf8mb4_general_ci
        WHERE JSON_UNQUOTE(JSON_EXTRACT(p.metadata, '$.callsign')) = ?
          AND p.citizenid != ?
          AND (pr.callsign IS NULL OR pr.callsign = '' OR pr.callsign = ?)
        LIMIT 1
    ]], { callsign, exceptCitizenid, callsign })
    if meta then
        return (meta.fullname and meta.fullname ~= '' and meta.fullname) or meta.citizenid
    end

    return nil
end

-- One-off repair. Until now SetMetaData was never pushed to the players table, so a
-- reassigned officer could keep their OLD callsign in players.metadata indefinitely —
-- which is why the picker attributed a stale number to them. mdt_profiles is the store
-- the MDT actually writes, so it wins; metadata is brought back into line with it.
AddEventHandler('onResourceStart', function(res)
    if res ~= GetCurrentResourceName() then return end

    local rows = MySQL.query.await([[
        SELECT p.citizenid,
               pr.callsign AS profile_callsign,
               JSON_UNQUOTE(JSON_EXTRACT(p.metadata, '$.callsign')) AS meta_callsign
        FROM players p
        INNER JOIN mdt_profiles pr ON pr.citizenid = p.citizenid COLLATE utf8mb4_general_ci COLLATE utf8mb4_general_ci
        WHERE pr.callsign IS NOT NULL AND pr.callsign <> ''
          AND JSON_UNQUOTE(JSON_EXTRACT(p.metadata, '$.callsign')) <> pr.callsign
    ]], {}) or {}

    if #rows == 0 then return end

    for _, r in ipairs(rows) do
        MySQL.update.await(
            "UPDATE players SET metadata = JSON_SET(metadata, '$.callsign', ?) WHERE citizenid = ?",
            { r.profile_callsign, r.citizenid }
        )
        ps.warn(('[callsigns] %s: metadata said "%s", profile says "%s" — corrected to the profile.')
            :format(tostring(r.citizenid), tostring(r.meta_callsign), tostring(r.profile_callsign)))
    end

    ps.warn(('[callsigns] Reconciled %d stale callsign(s) in player metadata.'):format(#rows))
end)

-- Check every configured callsign block once, on start. A bad range or a number
-- listed as both Reserved and Blocked otherwise only surfaces the day somebody opens
-- the picker and finds it broken.
AddEventHandler('onResourceStart', function(res)
    if res ~= GetCurrentResourceName() then return end

    local root = (Config and Config.Callsigns) or {}
    local function check(tbl, kind)
        for key, block in pairs(tbl or {}) do
            local cfg, problem = CallsignConfigFor(
                kind == 'job' and key or nil,
                kind == 'jobtype' and key or nil
            )
            if not cfg then
                ps.warn(('[callsigns] %s "%s": %s'):format(kind, tostring(key), tostring(problem)))
            else
                -- A number outside the range can never be picked, so listing it there
                -- means somebody meant something else.
                for n in pairs(cfg.Reserved) do
                    if n < cfg.Min or n > cfg.Max then
                        ps.warn(('[callsigns] %s "%s": Reserved %d is outside %d-%d and can never apply.')
                            :format(kind, tostring(key), n, cfg.Min, cfg.Max))
                    end
                end
                for n in pairs(cfg.Blocked) do
                    if n < cfg.Min or n > cfg.Max then
                        ps.warn(('[callsigns] %s "%s": Blocked %d is outside %d-%d and can never apply.')
                            :format(kind, tostring(key), n, cfg.Min, cfg.Max))
                    end
                end
            end
        end
    end

    check(root.JobTypes, 'jobtype')
    check(root.Jobs, 'job')
end)

--- Send an e-mail to a citizen through the configured phone resource.
--- Mirrors the lb-phone flow court.lua already uses: resolve the citizen's number,
--- ask the phone for the mail address behind it, then send.
--- Silent no-op when no phone resource is configured or running, so nothing that
--- calls this ever depends on a phone being installed.
--- @return boolean sent
function SendCitizenMail(citizenid, sender, subject, message)
    if not citizenid then return false end
    if not PhoneSendMail then return false end

    -- The whole number -> e-mail -> SendMail dance used to live here, hard
    -- wired to lb-phone's shape. It is now described in Config.Phone and
    -- performed by server/backend/phone.lua, so this and the court scheduler
    -- speak to whichever phone script is configured.
    return PhoneSendMail(citizenid, subject or '', message or '', sender)
end

exports('GetCitizenPhoneNumber', function(citizenid, fallback)
    return GetCitizenPhoneNumber(citizenid, fallback)
end)