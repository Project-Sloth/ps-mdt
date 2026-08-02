local resourceName = tostring(GetCurrentResourceName())

local function getEffectiveJobType(src)
    local jobType = ps.getJobType(src)
    local jobName = ps.getJobName(src)
    if Config.DojJobs then
        for _, name in ipairs(Config.DojJobs) do
            if name == jobName then return 'doj' end
        end
    end
    if Config.DojJobType and jobType == Config.DojJobType then return 'doj' end
    -- Normalise to a stable MDT domain (name + type aware) instead of returning
    -- the raw core job type, so EMS is detected even when its type isn't "ems".
    if IsEmsJob(jobName, jobType) then return 'ems' end
    return 'leo'
end

local function computeJobData(src)
    return {
        rank    = ps.getJobGradeName(src) or 'Officer',
        payRate = '$' .. (ps.getJobGradePay(src) or 300) .. '/hr',
    }
end

ps.registerCallback(resourceName .. ':server:getJobData', function(source)
    local src = source
    assert(src, 'Player ID cannot be nil')
    if not CheckAuth(src) then return {} end
    return computeJobData(src)
end)

local function computeReportStatistics()
    return Cache.getOrSet('dashboard:reportStats', Config.CacheTTL and Config.CacheTTL.ReportStats or 30, function()
        local response = MySQL.query.await([[
            SELECT
                COUNT(CASE WHEN datecreated >= NOW() - INTERVAL 1 WEEK THEN 1 END) AS totalThisWeek,
                COUNT(CASE WHEN datecreated >= NOW() - INTERVAL 2 WEEK AND datecreated < NOW() - INTERVAL 1 WEEK THEN 1 END) AS totalLastWeek
            FROM mdt_reports
        ]], {})

        local row = response and response[1] or { totalThisWeek = 0, totalLastWeek = 0 }
        return {
            totalThisWeek      = tonumber(row.totalThisWeek) or 0,
            changeFromLastWeek = (tonumber(row.totalThisWeek) or 0) - (tonumber(row.totalLastWeek) or 0),
        }
    end)
end

ps.registerCallback(resourceName .. ':server:getReportStatistics', function(source)
    local src = source
    assert(src, 'Player ID cannot be nil')
    if not CheckAuth(src) then return {} end
    return computeReportStatistics()
end)

local function computeTimeStatistics(src)
    local citizenid = ps.getIdentifier(src)
    if not citizenid then return {} end

    local rows = MySQL.query.await([[
        SELECT DATE(login_at) AS day,
               SUM(TIMESTAMPDIFF(SECOND, login_at, COALESCE(logout_at, NOW()))) AS seconds
        FROM mdt_profile_sessions
        WHERE citizenid = ?
          AND login_at >= DATE_SUB(NOW(), INTERVAL 7 DAY)
        GROUP BY DATE(login_at)
        ORDER BY day ASC
    ]], { citizenid })

    local secondsByDay = {}
    for _, row in ipairs(rows or {}) do
        secondsByDay[tostring(row.day)] = tonumber(row.seconds) or 0
    end

    local result = {}
    for i = 6, 0, -1 do
        local dayTs  = os.time() - (i * 24 * 60 * 60)
        local dayKey = os.date('%Y-%m-%d', dayTs)
        local label  = os.date('%a', dayTs)
        result[#result + 1] = {
            day   = label,
            hours = math.floor(((secondsByDay[dayKey] or 0) / 3600) * 10) / 10,
        }
    end
    return result
end

ps.registerCallback(resourceName .. ':server:getTimeStatistics', function(source)
    local src = source
    assert(src, 'Player ID cannot be nil')
    if not CheckAuth(src) then return {} end
    return computeTimeStatistics(src)
end)

-- Active warrants handled in server/backend/warrants.lua

local function computeBulletins()
    local rows = MySQL.query.await('SELECT id, content FROM mdt_bulletins ORDER BY id DESC')
    if not rows or #rows == 0 then
        return { { content = 'No bulletins found..' } }
    end
    return rows
end

ps.registerCallback(resourceName .. ':server:getBulletins', function(source)
    local src = source
    assert(src, 'Player ID cannot be nil')
    if not CheckAuth(src) then return {} end
    return computeBulletins()
end)

ps.registerCallback(resourceName .. ':server:createBulletin', function(source, payload)
    local src = source
    assert(src, 'Player ID cannot be nil')
    if not CheckAuth(src) then return { success = false, message = 'Unauthorized' } end
    if not RateLimitAction(src, 'createBulletin') then
        return { success = false, message = 'You are doing that too fast — wait a moment.' }
    end

    payload = payload or {}
    local content = payload.content
    if not content or content == '' then
        return { success = false, message = 'Bulletin content is required' }
    end

    local inserted = MySQL.insert.await('INSERT INTO mdt_bulletins (content) VALUES (?)', { content })
    if not inserted then
        return { success = false, message = 'Failed to create bulletin' }
    end

    Cache.invalidate('dashboard:bulletins')
    return { success = true, id = inserted }
end)

ps.registerCallback(resourceName .. ':server:deleteBulletin', function(source, payload)
    local src = source
    assert(src, 'Player ID cannot be nil')
    if not CheckAuth(src) then return { success = false, message = 'Unauthorized' } end

    payload = payload or {}
    local id = tonumber(payload.id)
    if not id then
        return { success = false, message = 'Invalid bulletin ID' }
    end

    MySQL.query.await('DELETE FROM mdt_bulletins WHERE id = ?', { id })
    Cache.invalidate('dashboard:bulletins')
    return { success = true }
end)

ps.registerCallback(resourceName .. ':server:getRecentReports', function(source, page, limit)
    local src      = source
    assert(src, 'Player ID cannot be nil')
    if not CheckAuth(src) then return {} end
    local pageNumber = math.max(1, tonumber(page) or 1)
    local pageSize   = math.min(50, math.max(1, tonumber(limit) or 10))

    local identifier = ps.getIdentifier(src)
    local job        = ps.getJobName(src)
    local jobType    = getEffectiveJobType(src)
    local offset     = (pageNumber - 1) * pageSize

    local rows = MySQL.query.await([[
        SELECT mr.id, mr.title, mr.type, mr.contentplaintext, mr.author, mr.authorplaintext, mr.datecreated, mr.dateupdated
        FROM mdt_reports mr
        LEFT JOIN mdt_reports_restrictions mrr ON mr.id = mrr.reportid
        WHERE (
            (? = 'doj' AND NOT EXISTS(
                SELECT 1 FROM mdt_reports_restrictions mrr_ems
                WHERE mrr_ems.reportid = mr.id AND mrr_ems.type = 'jobtype' AND mrr_ems.identifier = 'ems'
            ))
            OR (mrr.reportid IS NULL AND (? = 'leo' OR ? = 'ems'))
            OR (mrr.type = 'citizenid' AND mrr.identifier = ?)
            OR (mrr.type = 'job'       AND mrr.identifier = ?)
            OR (mrr.type = 'jobtype'   AND mrr.identifier = ?)
        )
        GROUP BY mr.id
        ORDER BY mr.datecreated DESC
        LIMIT ?
        OFFSET ?
    ]], { jobType, jobType, jobType, identifier, job, jobType, pageSize, offset })
    return rows or {}
end)

local function computeActiveBolos(src)
    local BOLOS = MySQL.query.await('SELECT id, type, subject_id, subject_name, reportId, notes, status FROM mdt_bolos WHERE status = ? ORDER BY id DESC', { 'active' })
    local result = {}
    for _, v in pairs(BOLOS or {}) do
        result[#result + 1] = {
            id       = v.id,
            reportId = v.reportId and tostring(v.reportId) or 'N/A',
            name     = v.subject_name or ps.getPlayerNameByIdentifier(v.subject_id) or 'Unknown',
            type     = v.type,
            notes    = v.notes or '',
            status   = v.status,
        }
    end
    return result
end

ps.registerCallback(resourceName .. ':server:getActiveBolos', function(source)
    local src = source
    assert(src, 'Player ID cannot be nil')
    if not CheckAuth(src) then return {} end
    return computeActiveBolos(src)
end)

local function computeActiveUnits()
    return Cache.getOrSet('dashboard:activeUnits', Config.CacheTTL and Config.CacheTTL.ActiveUnits or 10, function()
        return { count = ps.getJobTypeCount('leo') }
    end)
end

ps.registerCallback(resourceName .. ':server:getActiveUnits', function(source)
    local src = source
    assert(src, 'Player ID cannot be nil')
    if not CheckAuth(src) then return { count = 0 } end
    return computeActiveUnits()
end)

local function sanitizeDispatch(call)
    if not call or type(call) ~= 'table' then return nil end
    local sanitized = {
        id          = call.id,
        message     = call.message     or call.dispatchMessage or '',
        code        = call.code        or call.dispatchCode    or '',
        street      = call.street      or '',
        priority    = call.priority    or 0,
        time        = call.time        or 0,
        gender      = call.gender,
        plate       = call.plate,
        color       = call.color,
        model       = call.model,
        weapon      = call.weapon,
        heading     = call.heading,
        speed       = call.speed,
        callSign    = call.callSign,
        description = call.description,
        camId       = call.camId,
        firstColor  = call.firstColor,
        -- What the caller actually reported (911 text etc.) and any note a
        -- dispatcher pinned to the call inside ps-dispatch. Both were dropped
        -- here before, so assignments could never carry them along.
        information = call.information,
        dispatchNote = call.dispatchNote,
    }
    if call.coords then
        if type(call.coords) == 'vector3' or type(call.coords) == 'vector4' then
            sanitized.coords = { x = call.coords.x, y = call.coords.y, z = call.coords.z }
        elseif type(call.coords) == 'table' then
            sanitized.coords = { x = call.coords.x or call.coords[1], y = call.coords.y or call.coords[2], z = call.coords.z or call.coords[3] }
        end
    end
    sanitized.units = {}
    if call.units and type(call.units) == 'table' then
        for _, unit in pairs(call.units) do
            if type(unit) == 'table' then
                sanitized.units[#sanitized.units + 1] = {
                    citizenid = unit.citizenid,
                    charinfo  = unit.charinfo,
                    job       = unit.job,
                    metadata  = unit.metadata and { callsign = unit.metadata.callsign } or nil,
                }
            end
        end
    end
    if call.jobs and type(call.jobs) == 'table' then
        sanitized.jobs = {}
        for _, job in ipairs(call.jobs) do
            sanitized.jobs[#sanitized.jobs + 1] = job
        end
    end
    return sanitized
end

-- Latest open investigations for the dashboard.
local function computeOpenCases()
    local rows = MySQL.query.await([[
        SELECT id, case_number, title, status, priority, updated_at
        FROM mdt_cases
        WHERE status IN ('open', 'in_progress')
        ORDER BY updated_at DESC
        LIMIT 6
    ]])
    return rows or {}
end

-- Next few calendar entries (court/training/meetings) for the dashboard.
local function computeUpcomingHearings(src)
    local domain = (GetMdtDomain and GetMdtDomain(src)) or 'police'
    local rows = MySQL.query.await([[
        SELECT id, title, category, hearing_type, defendant_name, scheduled_at, location, status
        FROM mdt_court_hearings
        WHERE job_type = ?
          AND status IN ('scheduled', 'in_session')
          AND scheduled_at >= (NOW() - INTERVAL 1 HOUR)
        ORDER BY scheduled_at ASC
        LIMIT 6
    ]], { domain })
    return rows or {}
end

-- Globally dismissed calls (dispatcher action) — filtered out of every list.
-- Entries auto-expire so the table can't grow forever.
local DismissedDispatches = {}
local DISMISS_TTL = 2 * 60 * 60 -- seconds

-- One note per call: DispatchNotes[callId] = { text, author, updatedAt }.
-- Lives alongside the call; pruned on the same TTL and cleared on dismiss.
local DispatchNotes = {}

-- Manually created calls (from the MDT "Create Call" modal). These are owned by
-- the MDT so we control the id, note and initial units directly. They're merged
-- into the dispatch list alongside the provider's own calls.
local ManualDispatches = {}
local MANUAL_TTL = 2 * 60 * 60 -- seconds
local manualSeq = 0

local function pruneDismissed()
    local now = os.time()
    for id, at in pairs(DismissedDispatches) do
        if (now - at) > DISMISS_TTL then DismissedDispatches[id] = nil end
    end
    for id, note in pairs(DispatchNotes) do
        if note.updatedAt and (now - note.updatedAt) > DISMISS_TTL then DispatchNotes[id] = nil end
    end
    for id, call in pairs(ManualDispatches) do
        if call.time and (os.time() - math.floor(call.time / 1000)) > MANUAL_TTL then ManualDispatches[id] = nil end
    end
end

local function filterDismissed(list)
    pruneDismissed()
    if not next(DismissedDispatches) then return list end
    local out = {}
    for _, call in ipairs(list or {}) do
        if not DismissedDispatches[tostring(call.id)] then
            out[#out + 1] = call
        end
    end
    return out
end

-- ═══════════════════════════════════════════════════════════════════════════
-- Dispatch provider layer
-- Each provider returns a RAW call list in a ps-dispatch-like shape; the shared
-- sanitizeDispatch() below turns that into the MDT's final format. Adding a new
-- system means writing one fetch function here — the map, ticker, unit
-- assignment and dismiss logic never need to change.
-- ═══════════════════════════════════════════════════════════════════════════

local function resourceRunning(name)
    return GetResourceState(name) == 'started' or GetResourceState(name) == 'starting'
end

-- ps-dispatch: already exposes a normalized list via GetDispatchCalls().
local function fetchPsDispatch()
    local ok, calls = pcall(function()
        return exports['ps-dispatch'] and exports['ps-dispatch']:GetDispatchCalls() or {}
    end)
    if not ok then return {} end
    return calls or {}
end

-- qs-dispatch: calls carry callLocation / callCode{code,snippet} / message and a
-- responses/units list. Map those onto the ps-style fields sanitizeDispatch wants.
local function fetchQsDispatch()
    local ok, calls = pcall(function()
        local ex = exports['qs-dispatch']
        if not ex then return {} end
        -- qs exposes a couple of getter names across versions; try both.
        if ex.GetDispatchCalls then return ex:GetDispatchCalls() end
        if ex.GetActiveCalls   then return ex:GetActiveCalls()   end
        return {}
    end)
    if not ok or type(calls) ~= 'table' then return {} end

    local out = {}
    for _, c in pairs(calls) do
        if type(c) == 'table' then
            local code = c.code or (c.callCode and (c.callCode.code or c.callCode.snippet))
            out[#out + 1] = {
                id       = c.id or c.callId or c.dispatchId,
                message  = c.message,
                code     = code,
                codeName = c.callCode and c.callCode.snippet or nil,
                priority = c.priority or (c.blip and c.blip.priority) or 0,
                coords   = c.callLocation or c.coords or c.location,
                street   = c.street or c.street_1,
                time     = c.time or c.dispatchTime,
                gender   = c.sex or c.gender,
                plate    = c.vehicle_plate or c.plate,
                color    = c.vehicle_colour or c.color,
                model    = c.vehicle_label or c.model,
                units    = c.units or c.responses,
                jobs     = c.job or c.jobs,
                image    = c.image,
            }
        end
    end
    return out
end

-- cd_dispatch (Codesign): calls use title / message / coords and a unique_id.
local function fetchCdDispatch()
    local ok, calls = pcall(function()
        local ex = exports['cd_dispatch']
        if not ex then return {} end
        if ex.GetActiveCalls   then return ex:GetActiveCalls()   end
        if ex.GetDispatchCalls then return ex:GetDispatchCalls() end
        return {}
    end)
    if not ok or type(calls) ~= 'table' then return {} end

    local out = {}
    for _, c in pairs(calls) do
        if type(c) == 'table' then
            out[#out + 1] = {
                id       = c.id or c.unique_id or c.callId,
                message  = c.message,
                code     = c.code or c.title,
                codeName = c.title,
                priority = c.priority or 0,
                coords   = c.coords or c.origin or c.location,
                street   = c.street,
                time     = c.time,
                gender   = c.gender or c.sex,
                plate    = c.plate,
                color    = c.color,
                model    = c.model or c.vehicle,
                units    = c.units or c.responses,
                jobs     = c.job_table or c.jobs or c.job,
                image    = c.image,
            }
        end
    end
    return out
end

-- Resolve the configured provider and fetch raw calls. When none of the three
-- supported dispatch resources can be found, warn once (server console) so the
-- server owner knows the MDT has nothing to read from.
local dispatchWarned = false
local function resolveProvider()
    local provider = (Config and Config.Dispatch and Config.Dispatch.Provider) or 'auto'

    -- Explicit choice: honor it only if that resource is actually running.
    if provider == 'ps' or provider == 'qs' or provider == 'cd' then
        local resByProvider = { ps = 'ps-dispatch', qs = 'qs-dispatch', cd = 'cd_dispatch' }
        if resourceRunning(resByProvider[provider]) then return provider end
    end

    -- Auto-detect (also the fallback when an explicit choice isn't running).
    if resourceRunning('ps-dispatch') then return 'ps' end
    if resourceRunning('qs-dispatch') then return 'qs' end
    if resourceRunning('cd_dispatch') then return 'cd' end

    if not dispatchWarned then
        dispatchWarned = true
        print('^3[ps-mdt]^0 No supported dispatch resource detected (ps-dispatch, qs-dispatch or cd_dispatch). Dispatch calls will not appear on the map.')
    end
    return nil
end

local function fetchDispatchCalls()
    local provider = resolveProvider()
    if provider == 'qs' then return fetchQsDispatch() end
    if provider == 'cd' then return fetchCdDispatch() end
    if provider == 'ps' then return fetchPsDispatch() end
    return {}
end

-- The heavy part of building the dispatch list (provider fetch, manual-call
-- merge, dismiss filter, and sanitizing + note-attaching EVERY call) produces
-- the same result for every player — only the final job filter is per-player.
-- We cache that shared list for a short window so N open MDTs polling every
-- ~10s don't each redo the provider export + full sanitize pass. The cache is
-- invalidated immediately whenever a call/note/assignment changes.
local dispatchListCache = { ts = 0, list = nil }
-- Short TTL: long enough to collapse the burst of simultaneous polls from many
-- open MDTs (and the open-time fetch), short enough that a brand-new provider
-- alert still shows up promptly. Mutations from the MDT itself (notes, dismiss,
-- manual calls, assignments) invalidate instantly, so this only ever delays
-- calls created by the external dispatch resource, by at most this window.
local DISPATCH_CACHE_TTL = 2000 -- ms

local function invalidateDispatchCache()
    dispatchListCache.ts = 0
    dispatchListCache.list = nil
end

-- Provider attach/detach runs client → provider directly, so this server
-- never sees it and can't invalidate the dispatch-list cache itself — the
-- list a client refetches right after attaching would still show pre-attach
-- units for up to the cache TTL. Clients ping this after any provider
-- attach/detach. Per-player rate limit instead of a global throttle on
-- purpose: switching calls fires attach + detach back-to-back, and a global
-- cooldown would swallow the second invalidation, leaving the OLD call's
-- unit list stale until the next poll. Invalidation itself is free — the
-- limit only guards against a hostile client forcing constant provider-
-- export rebuilds.
RegisterNetEvent(resourceName .. ':server:touchDispatchCache', function()
    local src = source
    if not CheckAuth(src) then return end
    if not RateLimit(src, 'touchDispatchCache', 20, 10000) then return end
    invalidateDispatchCache()
end)

local function buildSanitizedDispatches()
    local now = GetGameTimer()
    if dispatchListCache.list and (now - dispatchListCache.ts) < DISPATCH_CACHE_TTL then
        return dispatchListCache.list
    end

    local recentDispatches = fetchDispatchCalls() or {}

    -- Merge MDT-created calls in alongside the provider's own calls.
    for _, call in pairs(ManualDispatches) do
        recentDispatches[#recentDispatches + 1] = call
    end

    recentDispatches = filterDismissed(recentDispatches)

    -- Sanitize + attach notes once (player-independent).
    local built = {}
    for _, call in ipairs(recentDispatches) do
        local sanitized = sanitizeDispatch(call)
        if sanitized then
            local note = sanitized.id ~= nil and DispatchNotes[tostring(sanitized.id)] or nil
            if note then
                sanitized.note = { text = note.text, author = note.author, updatedAt = note.updatedAt }
            end
            built[#built + 1] = sanitized
        end
    end

    dispatchListCache.list = built
    dispatchListCache.ts = now
    return built
end

-- Auto-status and the assignment notify need one call's code/coords resolved
-- SERVER-side (the client must never do a blocking list round-trip for it —
-- see the coalescing note on GetRecentDispatch). Reads the same cached
-- sanitized list the MDT serves, so it covers provider calls AND MDT-created
-- manual calls without extra export hits. Global on purpose; used guarded.
function GetDispatchInfoById(id)
    id = tostring(id)
    for _, call in ipairs(buildSanitizedDispatches()) do
        if tostring(call.id) == id then
            local code = type(call.code) == 'string' and call.code ~= '' and call.code or nil
            local street = type(call.street) == 'string' and call.street ~= '' and call.street or nil
            local message = type(call.message) == 'string' and call.message ~= '' and call.message or nil
            local information = type(call.information) == 'string' and call.information ~= '' and call.information or nil
            local dispatchNote = type(call.dispatchNote) == 'string' and call.dispatchNote ~= '' and call.dispatchNote or nil
            return {
                code = code, coords = call.coords, street = street, message = message,
                information = information, dispatchNote = dispatchNote,
            }
        end
    end
    return nil
end

local function computeRecentDispatches(src)
    local dispatches = buildSanitizedDispatches()

    -- Per-player job filter is cheap (a table scan, no DB/export), so it stays
    -- outside the cache.
    if Config and Config.Dispatch and Config.Dispatch.FilterByJob == true then
        local jobName = ps.getJobName(src)
        local jobType = ps.getJobType and ps.getJobType(src) or nil
        if jobName then
            local filtered = {}
            for _, call in ipairs(dispatches) do
                if not call.jobs or #call.jobs == 0 then
                    filtered[#filtered + 1] = call
                else
                    for _, job in ipairs(call.jobs) do
                        if job == jobName or job == jobType then
                            filtered[#filtered + 1] = call
                            break
                        end
                    end
                end
            end
            dispatches = filtered
        end
    end

    return dispatches
end

ps.registerCallback(resourceName .. ':server:getRecentDispatches', function(source)
    local src = source
    assert(src, 'Player ID cannot be nil')
    if not CheckAuth(src) then return {} end
    return computeRecentDispatches(src)
end)

-- Impound at a glance: how much is being held, how much money is outstanding and
-- how long the oldest car has been sitting there. Storage fees are derived from
-- the impound date (see server/backend/impound.lua), so the outstanding total has
-- to be worked out the same way here rather than read from a column.
local function computeImpoundMetrics(safeCount)
    local cfg = (Config and Config.Impound) or {}

    -- Nothing at all when the feature is off, rather than a row of zeroes. The
    -- dashboard tile is already conditional on there being figures, so an empty
    -- table removes it — and three database queries a dashboard load are saved
    -- on servers that do not impound.
    if cfg.Enabled == false then
        return { held = 0, outstanding = 0, oldestDays = 0, impoundedLast7 = 0 }
    end

    local storage = cfg.Storage or {}
    local perDay  = storage.PerDay or 0
    local maxDays = storage.MaxDays or 0

    local held = safeCount("SELECT COUNT(*) FROM mdt_impound WHERE status = 'active'")
    local impoundedLast7 = safeCount(
        "SELECT COUNT(*) FROM mdt_impound WHERE time >= UNIX_TIMESTAMP(NOW() - INTERVAL 7 DAY)")

    local rows = {}
    local ok, res = pcall(MySQL.query.await,
        "SELECT fee, fee_paid, time FROM mdt_impound WHERE status = 'active'")
    if ok and res then rows = res end

    local outstanding, oldestDays = 0, 0
    local now = os.time()
    for _, r in ipairs(rows) do
        local days = math.floor((now - (r.time or now)) / 86400)
        if days < 0 then days = 0 end
        if days > oldestDays then oldestDays = days end

        local paid = r.fee_paid == true or r.fee_paid == 1
        if not paid then
            local billable = math.min(days, maxDays)
            outstanding = outstanding + (r.fee or 0) + (billable * perDay)
        end
    end

    return {
        held           = held,
        outstanding    = outstanding,
        oldestDays     = oldestDays,
        impoundedLast7 = impoundedLast7,
    }
end

local function computeUsageMetrics()
    return Cache.getOrSet('dashboard:usageMetrics', Config.CacheTTL and Config.CacheTTL.UsageMetrics or 60, function()
        local function safeCount(query, params)
            local ok, result = pcall(MySQL.scalar.await, query, params or {})
            return ok and (tonumber(result) or 0) or 0
        end
        return {
            totals = {
                reports       = safeCount('SELECT COUNT(*) FROM mdt_reports'),
                arrests       = safeCount('SELECT COUNT(*) FROM mdt_arrests'),
                activeWarrants = safeCount('SELECT COUNT(*) FROM mdt_reports_warrants WHERE expirydate >= NOW()'),
            },
            windows = {
                reportsLast7   = safeCount('SELECT COUNT(*) FROM mdt_reports WHERE datecreated >= NOW() - INTERVAL 7 DAY'),
                reportsLast30  = safeCount('SELECT COUNT(*) FROM mdt_reports WHERE datecreated >= NOW() - INTERVAL 30 DAY'),
                arrestsLast7   = safeCount('SELECT COUNT(*) FROM mdt_arrests WHERE created_at >= NOW() - INTERVAL 7 DAY'),
                arrestsLast30  = safeCount('SELECT COUNT(*) FROM mdt_arrests WHERE created_at >= NOW() - INTERVAL 30 DAY'),
            },
            impound = computeImpoundMetrics(safeCount),
        }
    end)
end

ps.registerCallback(resourceName .. ':server:getUsageMetrics', function(source)
    local src = source
    if not CheckAuth(src) then return {} end
    return computeUsageMetrics()
end)

-- ============================================================================
--  Aggregate: one round-trip for the whole dashboard.
--  The frontend previously fired ~9 separate NUI callbacks on open (one per
--  widget). This bundles them into a single callback so opening the MDT does
--  one server round-trip + one cb() serialisation instead of nine, which is
--  the bulk of the on-open client spike.
-- ============================================================================
ps.registerCallback(resourceName .. ':server:getDashboard', function(source)
    local src = source
    if not CheckAuth(src) then return {} end
    return {
        jobData          = computeJobData(src),
        upcomingHearings = computeUpcomingHearings(src),
        openCases        = computeOpenCases(),
        reportStatistics = computeReportStatistics(),
        timeStatistics   = computeTimeStatistics(src),
        activeWarrants   = (GetActiveWarrantsData and GetActiveWarrantsData(src)) or {},
        bulletins        = computeBulletins(),
        activeBolos      = computeActiveBolos(src),
        activeUnits      = computeActiveUnits(),
        -- The frontend already reads usageMetrics off this payload but the server
        -- never sent it, so the numbers (and the impound tile) stayed empty.
        usageMetrics     = computeUsageMetrics(),
        recentDispatches = computeRecentDispatches(src),
        usageMetrics     = computeUsageMetrics(),
    }
end)
-- Human-readable description of a call for audit labels, e.g. "10-71 (Shooting)"
-- or "call #mdt-…" as a fallback. Reads from the cached/known call data.
local function describeCall(id)
    id = tostring(id)
    local manual = ManualDispatches[id]
    if manual then
        local code = manual.code or 'Call'
        local msg  = manual.message and manual.message ~= '' and manual.message or nil
        return msg and ('%s (%s)'):format(code, msg) or code
    end
    return ('call #%s'):format(id)
end

-- Dispatcher: globally dismiss a call — it disappears from every MDT.
ps.registerCallback(resourceName .. ':server:dismissDispatch', function(source, data)
    local src = source
    if not CheckAuth(src) then return { success = false } end
    if not CheckPermission(src, 'dispatch_assign') then
        return { success = false, error = 'No permission' }
    end
    data = data or {}
    local id = data.dispatch_id and tostring(data.dispatch_id) or nil
    if not id then return { success = false, error = 'Invalid request' } end

    local label = describeCall(id)
    DismissedDispatches[id] = os.time()
    DispatchNotes[id] = nil -- note dies with the call
    ManualDispatches[id] = nil -- MDT-created calls are removed outright
    -- Auto-status: everyone en route / on scene for this call goes back to
    -- available (only if their status is still the automation's — see
    -- auto_status.lua). Guarded so the module can be absent.
    if AutoStatusCallClosed then AutoStatusCallClosed(id) end
    if ps.auditLog then
        ps.auditLog(src, 'dispatch_dismiss', 'dispatch', id, {
            dispatch_id  = id,
            action_label = ('Dismissed %s for all units'):format(label),
        })
    end
    -- Nudge every open MDT to refresh its (now filtered) dispatch list.
    invalidateDispatchCache()
    TriggerClientEvent(resourceName .. ':client:dispatchDismissed', -1, id)
    return { success = true }
end)

-- ---------------------------------------------------------------------------
-- Dispatcher: per-call notes (one note per call).
-- Notes are attached to each call in computeRecentDispatches and shown to
-- assigned units. Editing a note re-notifies everyone currently on the call.
-- ---------------------------------------------------------------------------
local NOTE_MAX = 300

-- Resolve the source IDs of the units currently attached to a call, so we can
-- re-notify them when a note changes. Reads back the live provider call list.
local function getAssignedSources(dispatchId)
    local sources = {}
    local calls = fetchDispatchCalls()
    for _, call in ipairs(calls or {}) do
        if tostring(call.id) == tostring(dispatchId) and type(call.units) == 'table' then
            local okCore, QBCore = pcall(function() return exports['qb-core']:GetCoreObject() end)
            if not okCore then QBCore = nil end
            for _, unit in pairs(call.units) do
                local cid = type(unit) == 'table' and unit.citizenid or nil
                if cid then
                    local tSrc = nil
                    if ps.getPlayerByIdentifier then
                        local p = ps.getPlayerByIdentifier(cid)
                        tSrc = p and (p.PlayerData and p.PlayerData.source or p.source) or nil
                    end
                    if not tSrc and QBCore and QBCore.Functions.GetPlayerByCitizenId then
                        local p = QBCore.Functions.GetPlayerByCitizenId(cid)
                        tSrc = p and p.PlayerData and p.PlayerData.source or nil
                    end
                    if tSrc then sources[#sources + 1] = tSrc end
                end
            end
            break
        end
    end
    return sources
end

ps.registerCallback(resourceName .. ':server:setDispatchNote', function(source, data)
    local src = source
    if not CheckAuth(src) then return { success = false } end
    if not CheckPermission(src, 'dispatch_notes') then
        return { success = false, error = 'No permission' }
    end

    data = data or {}
    local id = data.dispatch_id and tostring(data.dispatch_id) or nil
    local text = type(data.text) == 'string' and data.text or ''
    text = text:gsub('^%s+', ''):gsub('%s+$', '')
    if not id then return { success = false, error = 'Invalid request' } end
    if text == '' then return { success = false, error = 'Note cannot be empty' } end
    if #text > NOTE_MAX then text = text:sub(1, NOTE_MAX) end

    local existed = DispatchNotes[id] ~= nil
    local okName, author = pcall(function()
        if ps.getCharInfo then
            return (ps.getCharInfo('firstname', src) or '') .. ' ' .. (ps.getCharInfo('lastname', src) or '')
        end
        return nil
    end)
    if not okName then author = nil end
    if author then author = author:gsub('^%s+', ''):gsub('%s+$', '') end
    DispatchNotes[id] = { text = text, author = (author ~= '' and author) or nil, updatedAt = os.time() }

    if ps.auditLog then
        local label = describeCall(id)
        ps.auditLog(src, existed and 'dispatch_note_edit' or 'dispatch_note_add', 'dispatch', id, {
            dispatch_id  = id,
            note         = text,
            action_label = existed
                and ('Edited the note on %s'):format(label)
                or  ('Added a note to %s'):format(label),
        })
    end

    -- Tell every open MDT to refresh (note now travels with the call).
    invalidateDispatchCache()
    TriggerClientEvent(resourceName .. ':client:dispatchNoteChanged', -1, id)

    -- If units are already on the call, re-notify them that the note changed.
    if existed then
        for _, tSrc in ipairs(getAssignedSources(id)) do
            TriggerClientEvent(resourceName .. ':client:dispatchNoteNotify', tSrc, { text = text })
        end
    end

    return { success = true }
end)

ps.registerCallback(resourceName .. ':server:deleteDispatchNote', function(source, data)
    local src = source
    if not CheckAuth(src) then return { success = false } end
    if not CheckPermission(src, 'dispatch_notes') then
        return { success = false, error = 'No permission' }
    end
    data = data or {}
    local id = data.dispatch_id and tostring(data.dispatch_id) or nil
    if not id then return { success = false, error = 'Invalid request' } end

    local label = describeCall(id)
    DispatchNotes[id] = nil
    if ps.auditLog then
        ps.auditLog(src, 'dispatch_note_delete', 'dispatch', id, {
            dispatch_id  = id,
            action_label = ('Removed the note from %s'):format(label),
        })
    end
    invalidateDispatchCache()
    TriggerClientEvent(resourceName .. ':client:dispatchNoteChanged', -1, id)
    return { success = true }
end)

-- Self attach/detach for MANUAL calls (provider calls handle this themselves).
-- No dispatch permission needed — you're only touching your own attachment.
ps.registerCallback(resourceName .. ':server:selfDispatchAttach', function(source, data)
    local src = source
    if not CheckAuth(src) then return { success = false } end
    data = data or {}
    local id = data.dispatch_id and tostring(data.dispatch_id) or nil
    local call = id and ManualDispatches[id] or nil
    if not call then return { success = false, error = 'Unknown call' } end

    local cid = ps.getIdentifier and ps.getIdentifier(src) or nil
    if not cid then return { success = false } end
    call.units = call.units or {}

    if data.action == 'detach' then
        for i = #call.units, 1, -1 do
            if call.units[i].citizenid == cid then table.remove(call.units, i) end
        end
    else
        local exists = false
        for _, u in ipairs(call.units) do if u.citizenid == cid then exists = true break end end
        if not exists then
            local okFirst, firstname = pcall(function() return ps.getCharInfo('firstname', src) end)
            local okLast,  lastname  = pcall(function() return ps.getCharInfo('lastname', src) end)
            call.units[#call.units + 1] = {
                citizenid = cid,
                charinfo  = {
                    firstname = okFirst and firstname or nil,
                    lastname  = okLast and lastname or nil,
                },
                metadata  = { callsign = ps.getMetadata and ps.getMetadata(src, 'callsign') or nil },
            }
        end
    end

    invalidateDispatchCache()
    TriggerClientEvent(resourceName .. ':client:dispatchNoteChanged', -1, id)
    return { success = true }
end)

-- ---------------------------------------------------------------------------
-- Dispatcher: create a manual call from the MDT "Create Call" modal.
-- These are owned by the MDT (we control the id/note/units) and merged into the
-- dispatch list, so they flow into the ticker/map/assignment like any call —
-- without touching the underlying dispatch resource.
-- ---------------------------------------------------------------------------
ps.registerCallback(resourceName .. ':server:createManualDispatch', function(source, data)
    local src = source
    if not CheckAuth(src) then return { success = false } end
    if not CheckPermission(src, 'dispatch_assign') then
        return { success = false, error = 'No permission' }
    end

    data = data or {}
    local code     = type(data.code) == 'string' and data.code or ''
    local title    = type(data.title) == 'string' and data.title or ''
    local coords   = type(data.coords) == 'table' and data.coords or nil
    title = title:gsub('^%s+', ''):gsub('%s+$', '')

    if code == '' then return { success = false, error = 'A 10-code is required' } end
    if not coords or not tonumber(coords.x) or not tonumber(coords.y) then
        return { success = false, error = 'Pick a location on the map' }
    end

    -- Title falls back to the code's label (sent by the client from config).
    if title == '' then
        title = type(data.label) == 'string' and data.label:gsub('^%s+', ''):gsub('%s+$', '') or ''
    end
    if title == '' then title = code end

    -- Priority is derived from the code/title keywords (1 high / 2 med / 3 low),
    -- so it doesn't need to be configured per code.
    local function derivePriority(hay)
        hay = (hay or ''):lower()
        if hay:find('shoot') or hay:find('pursuit') or hay:find('robber') or hay:find('assist')
            or hay:find('10%-13') or hay:find('10%-71') or hay:find('10%-80') or hay:find('10%-90')
            or hay:find('officer') or hay:find('weapon') or hay:find('armed') then
            return 1
        end
        if hay:find('accident') or hay:find('ambulance') or hay:find('fire') or hay:find('disturb')
            or hay:find('suspicious') or hay:find('911') or hay:find('10%-52') or hay:find('10%-53') then
            return 2
        end
        return 3
    end
    local priority = derivePriority(code .. ' ' .. title)

    manualSeq = manualSeq + 1
    local id = 'mdt-' .. os.time() .. '-' .. manualSeq

    local jobs = nil
    if type(data.jobs) == 'table' and #data.jobs > 0 then
        jobs = data.jobs
    end

    ManualDispatches[id] = {
        id       = id,
        code     = code,
        message  = title,
        priority = priority,
        time     = os.time() * 1000, -- ms, matches the ticker's age display
        coords   = { x = tonumber(coords.x), y = tonumber(coords.y), z = tonumber(coords.z) or 0.0 },
        street   = type(data.street) == 'string' and data.street or nil,
        units    = {},
        jobs     = jobs,
        manual   = true,
    }

    -- Optional note straight from the modal.
    local note = type(data.note) == 'string' and data.note:gsub('^%s+', ''):gsub('%s+$', '') or ''
    if note ~= '' then
        local okName, author = pcall(function()
            if ps.getCharInfo then
                return (ps.getCharInfo('firstname', src) or '') .. ' ' .. (ps.getCharInfo('lastname', src) or '')
            end
            return nil
        end)
        if not okName then author = nil end
        if author then author = author:gsub('^%s+', ''):gsub('%s+$', '') end
        DispatchNotes[id] = { text = note:sub(1, 300), author = (author ~= '' and author) or nil, updatedAt = os.time() }
    end

    if ps.auditLog then
        local label = (title and title ~= '' and title ~= code) and ('%s (%s)'):format(code, title) or code
        local streetPart = (type(data.street) == 'string' and data.street ~= '') and (' at %s'):format(data.street) or ''
        ps.auditLog(src, 'dispatch_create', 'dispatch', id, {
            dispatch_id  = id,
            code         = code,
            title        = title,
            action_label = ('Created %s%s'):format(label, streetPart),
        })
    end

    -- Broadcast so open MDTs pick the new call up immediately.
    invalidateDispatchCache()
    TriggerClientEvent(resourceName .. ':client:dispatchNoteChanged', -1, id)
    return { success = true, id = id }
end)

-- ---------------------------------------------------------------------------
-- Dispatcher: assign or detach OTHER units to/from a dispatch call.
-- The actual attach runs on the TARGET client (same path as self-attach via
-- ps-dispatch), which also sets their waypoint and notifies them. This keeps
-- ps-dispatch's unit bookkeeping identical to a self-attach.
-- ---------------------------------------------------------------------------
ps.registerCallback(resourceName .. ':server:assignToDispatch', function(source, data)
    local src = source
    if not CheckAuth(src) then return { success = false } end
    if not CheckPermission(src, 'dispatch_assign') then
        return { success = false, error = 'No permission' }
    end

    data = data or {}
    local dispatchId = data.dispatch_id
    local action = data.action == 'detach' and 'detach' or 'attach'
    local citizenids = type(data.citizenids) == 'table' and data.citizenids or {}
    if not dispatchId or #citizenids == 0 then
        return { success = false, error = 'Invalid request' }
    end

    local okCore, QBCore = pcall(function() return exports['qb-core']:GetCoreObject() end)
    if not okCore then QBCore = nil end

    -- Manual (MDT-created) calls keep their unit list on the server, since the
    -- dispatch provider doesn't know about them.
    local manualCall = ManualDispatches[tostring(dispatchId)]

    local hit, miss = 0, 0
    local assignedNames = {} -- for a readable audit label
    local noteEntry = DispatchNotes[tostring(dispatchId)]
    local noteText = noteEntry and noteEntry.text or nil
    for _, cid in ipairs(citizenids) do
        local targetSrc = nil
        local targetPly = nil
        if ps.getPlayerByIdentifier then
            targetPly = ps.getPlayerByIdentifier(cid)
            targetSrc = targetPly and (targetPly.PlayerData and targetPly.PlayerData.source or targetPly.source) or nil
        end
        if not targetSrc and QBCore and QBCore.Functions.GetPlayerByCitizenId then
            targetPly = QBCore.Functions.GetPlayerByCitizenId(cid)
            targetSrc = targetPly and targetPly.PlayerData and targetPly.PlayerData.source or nil
        end

        -- Remember the officer's name (falls back to the citizenid) for the log.
        local ci = targetPly and targetPly.PlayerData and targetPly.PlayerData.charinfo or nil
        assignedNames[#assignedNames + 1] = ci and (ci.firstname .. ' ' .. ci.lastname) or cid

        -- For manual calls, maintain the unit list ourselves — do this even if
        -- the unit is offline so a detach always cleans the roster.
        if manualCall then
            manualCall.units = manualCall.units or {}
            if action == 'detach' then
                for i = #manualCall.units, 1, -1 do
                    if manualCall.units[i].citizenid == cid then table.remove(manualCall.units, i) end
                end
            else
                local exists = false
                for _, u in ipairs(manualCall.units) do
                    if u.citizenid == cid then exists = true break end
                end
                if not exists then
                    local pd = targetPly and targetPly.PlayerData or nil
                    manualCall.units[#manualCall.units + 1] = {
                        citizenid = cid,
                        charinfo  = pd and pd.charinfo or nil,
                        job       = pd and pd.job or nil,
                        metadata  = pd and pd.metadata and { callsign = pd.metadata.callsign } or nil,
                    }
                end
            end
        end

        if targetSrc then
            local info = GetDispatchInfoById(dispatchId) or {}

            -- Assignment as a real dispatch alert: the officer gets a full
            -- alert card (map thumbnail, 10-code, dispatcher note) through
            -- ps-dispatch's SendTargetedAlert export instead of a plain
            -- notify. Self-gating: on ps-dispatch builds without the export
            -- the pcall fails, alertSent stays false and the client falls
            -- back to its classic notify — no config switch needed.
            local alertSent = false
            -- Alert cards are a ps-dispatch bonus, not a requirement: the MDT
            -- also runs on qs-dispatch/cd_dispatch or with no dispatch
            -- resource at all. Checking the resource state first keeps the
            -- common standalone case free of a thrown-and-caught error, and
            -- the pcall still covers ps-dispatch builds that predate the
            -- SendTargetedAlert export. Either way the classic notify below
            -- takes over whenever alertSent stays false.
            if action == 'attach' and GetResourceState('ps-dispatch') == 'started' then
                -- pcall returns (ok, ...) — the previous version assigned only
                -- `ok`, so a rejected payload still counted as "sent" and
                -- suppressed the fallback notify. Both are checked now.
                local ok, sent = pcall(function()
                    return exports['ps-dispatch']:SendTargetedAlert({ targetSrc }, {
                        -- Headline is the actual call, not a generic label.
                        message = info.message or ('Call #' .. tostring(dispatchId)),
                        code = info.code or 'ASSIGN',
                        codeName = 'mdtassign',
                        icon = 'fas fa-headset',
                        priority = 2,
                        coords = data.coords and { x = data.coords.x, y = data.coords.y, z = 0 } or nil,
                        street = info.street,
                        -- Caller's own report stays in `information`; every
                        -- dispatcher instruction (the note written for this
                        -- assignment plus any note already pinned to the call
                        -- in ps-dispatch) goes into the tagged dispatch note,
                        -- so the unit sees WHAT happened and WHAT to do.
                        information = info.information,
                        dispatchNote = (function()
                            local parts = {}
                            if noteText and noteText ~= '' then parts[#parts + 1] = noteText end
                            if info.dispatchNote and info.dispatchNote ~= noteText then
                                parts[#parts + 1] = info.dispatchNote
                            end
                            return #parts > 0 and table.concat(parts, ' · ') or nil
                        end)(),
                        -- The dispatcher already set this unit's waypoint, so
                        -- the alert shows an assignment confirmation instead
                        -- of a respond prompt.
                        assigned = true,
                        alertTime = 12,
                    })
                end)
                alertSent = ok and sent == true
                if not ok then
                    ps.debug('SendTargetedAlert failed:', tostring(sent))
                end
            end

            TriggerClientEvent(resourceName .. ':client:dispatchAssign', targetSrc, {
                id = dispatchId,
                action = action,
                coords = data.coords, -- {x, y} for waypoint (attach only)
                note = noteText,      -- included in the assignment notify
                manual = manualCall ~= nil, -- skip provider attach for manual calls
                -- The alert card replaces the text notify when it went out.
                alertSent = alertSent,
                -- 10-code for the notify, resolved from the cached sanitized
                -- list — works for provider AND manual calls, and spares the
                -- client a blocking list round-trip.
                code = info.code,
            })
            hit = hit + 1
        else
            miss = miss + 1
        end
    end

    -- Manual call unit changes: refresh open MDTs.
    if manualCall then
        invalidateDispatchCache()
        TriggerClientEvent(resourceName .. ':client:dispatchNoteChanged', -1, tostring(dispatchId))
    end

    if ps.auditLog then
        local label = describeCall(dispatchId)
        local who
        if #assignedNames == 1 then
            who = assignedNames[1]
        elseif #assignedNames == 2 then
            who = assignedNames[1] .. ' and ' .. assignedNames[2]
        else
            who = ('%d officers'):format(#assignedNames)
        end
        ps.auditLog(src, 'dispatch_' .. action .. '_units', 'dispatch', tostring(dispatchId), {
            dispatch_id  = tostring(dispatchId),
            officers     = assignedNames,
            count        = hit,
            action_label = action == 'detach'
                and ('Removed %s from %s'):format(who, label)
                or  ('Assigned %s to %s'):format(who, label),
        })
    end
    return { success = hit > 0, assigned = hit, offline = miss }
end)