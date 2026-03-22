
local resourceName = tostring(GetCurrentResourceName())

ps.registerCallback(resourceName .. ':server:getJobData', function(source)
    local src = source
    assert(src, 'Player ID cannot be nil')
    local response = {
        rank = ps.getJobGradeName(src) or "Officer",
        payRate = "$" .. (ps.getJobGradePay(src) or 300) .. "/hr",
    }
    return response
end)

ps.registerCallback(resourceName .. ':server:getReportStatistics', function(source)
    local src = source
    assert(src, 'Player ID cannot be nil')

    return Cache.getOrSet('dashboard:reportStats', Config.CacheTTL and Config.CacheTTL.ReportStats or 30, function()
        local response = MySQL.query.await([[
            SELECT
                COUNT(CASE WHEN datecreated >= NOW() - INTERVAL 1 WEEK THEN 1 END) AS totalThisWeek,
                COUNT(CASE WHEN datecreated >= NOW() - INTERVAL 2 WEEK AND datecreated < NOW() - INTERVAL 1 WEEK THEN 1 END) AS totalLastWeek
            FROM mdt_reports
        ]], {})

        local row = response and response[1] or { totalThisWeek = 0, totalLastWeek = 0 }
        local reportStatistics = {
            totalThisWeek = tonumber(row.totalThisWeek) or 0,
            changeFromLastWeek = (tonumber(row.totalThisWeek) or 0) - (tonumber(row.totalLastWeek) or 0)
        }
        ps.debug('Report Statistics: ', reportStatistics)
        return reportStatistics
    end)
end)

local function parseDateOnly(value)
    if not value then
        return nil
    end
    local year, month, day = tostring(value):match('^(%d%d%d%d)%-(%d%d)%-(%d%d)$')
    if not year then
        return nil
    end
    return os.time({ year = tonumber(year), month = tonumber(month), day = tonumber(day), hour = 0 })
end

ps.registerCallback(resourceName .. ':server:getTimeStatistics', function(source)
    local src = source
    assert(src, 'Player ID cannot be nil')
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
        local dayTs = os.time() - (i * 24 * 60 * 60)
        local dayKey = os.date('%Y-%m-%d', dayTs)
        local label = os.date('%a', dayTs)
        local seconds = secondsByDay[dayKey] or 0
        result[#result + 1] = {
            day = label,
            hours = math.floor((seconds / 3600) * 10) / 10
        }
    end

    return result
end)

-- Active warrants handled in server/backend/warrants.lua

ps.registerCallback(resourceName .. ':server:getBulletins', function(source)
    local src = source
    assert(src, 'Player ID cannot be nil')
    if not CheckAuth(src) then return {} end
    local rows = MySQL.query.await('SELECT id, content FROM mdt_bulletins ORDER BY id DESC')
    if not rows or #rows == 0 then
        return { { content = 'No bulletins found..' } }
    end
    return rows
end)

ps.registerCallback(resourceName .. ':server:createBulletin', function(source, payload)
    local src = source
    assert(src, 'Player ID cannot be nil')
    if not CheckAuth(src) then return { success = false, message = 'Unauthorized' } end

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
    local src = source
    assert(src, 'Player ID cannot be nil')
    local pageNumber = tonumber(page) or 1
    if pageNumber < 1 then
        pageNumber = 1
    end

    local pageSize = tonumber(limit) or 10
    if pageSize < 1 then
        pageSize = 10
    end
    if pageSize > 50 then
        pageSize = 50
    end

    local identifier = ps.getIdentifier(src)
    local job = ps.getJobName(src)
    local jobType = ps.getJobType(src)

    local offset = (pageNumber - 1) * pageSize
    local rows = MySQL.query.await([[
        SELECT mr.id, mr.title, mr.type, mr.contentplaintext, mr.author, mr.authorplaintext, mr.datecreated, mr.dateupdated
        FROM mdt_reports mr
        LEFT JOIN mdt_reports_restrictions mrr ON mr.id = mrr.reportid
        WHERE (
            (mrr.reportid IS NULL AND ? = 'leo')
            OR (mrr.type = 'citizenid' AND mrr.identifier = ?)
            OR (mrr.type = 'job' AND mrr.identifier = ?)
            OR (mrr.type = 'jobtype' AND mrr.identifier = ?)
        )
        GROUP BY mr.id
        ORDER BY mr.datecreated DESC
        LIMIT ?
        OFFSET ?
    ]], { jobType, identifier, job, jobType, pageSize, offset })
    return rows or {}
end)

ps.registerCallback(resourceName .. ':server:getActiveBolos', function(source)
    local src = source
    assert(src, 'Player ID cannot be nil')
    if not CheckAuth(src) then return {} end
    local BOLOS = MySQL.query.await('SELECT * FROM mdt_bolos WHERE status = ? ORDER BY id DESC', { 'active' })
    local result = {}
    for _, v in pairs(BOLOS or {}) do
        local formattedBolo = {
            id = v.id,
            reportId = v.reportId and tostring(v.reportId) or 'N/A',
            name = v.subject_name or ps.getPlayerNameByIdentifier(v.subject_id) or 'Unknown',
            type = v.type,
            notes = v.notes or '',
            status = v.status,
        }
        table.insert(result, formattedBolo)
    end
    ps.debug('Fetched ' .. #result .. ' active BOLOs from database for source ' .. src, result)
    return result
end)

ps.registerCallback(resourceName .. ':server:getActiveUnits', function(source)
    local src = source
    assert(src, 'Player ID cannot be nil')
    return Cache.getOrSet('dashboard:activeUnits', Config.CacheTTL and Config.CacheTTL.ActiveUnits or 10, function()
        return { count = ps.getJobTypeCount('leo') }
    end)
end)

-- Sanitize dispatch data for safe serialization through ps.callback
-- ps-dispatch objects contain vectors/coords that msgpack can't serialize
local function sanitizeDispatch(call)
    if not call or type(call) ~= 'table' then return nil end

    local sanitized = {
        id = call.id,
        message = call.message or call.dispatchMessage or '',
        code = call.code or call.dispatchCode or '',
        street = call.street or '',
        priority = call.priority or 0,
        time = call.time or 0,
        gender = call.gender,
        plate = call.plate,
        color = call.color,
        model = call.model,
        weapon = call.weapon,
        heading = call.heading,
        speed = call.speed,
        callSign = call.callSign,
        description = call.description,
        camId = call.camId,
        firstColor = call.firstColor,
    }

    -- Sanitize coords (vectors can't serialize)
    if call.coords then
        if type(call.coords) == 'vector3' or type(call.coords) == 'vector4' then
            sanitized.coords = { x = call.coords.x, y = call.coords.y, z = call.coords.z }
        elseif type(call.coords) == 'table' then
            sanitized.coords = { x = call.coords.x or call.coords[1], y = call.coords.y or call.coords[2], z = call.coords.z or call.coords[3] }
        end
    end

    -- Sanitize units array
    sanitized.units = {}
    if call.units and type(call.units) == 'table' then
        for _, unit in pairs(call.units) do
            if type(unit) == 'table' then
                sanitized.units[#sanitized.units + 1] = {
                    citizenid = unit.citizenid,
                    charinfo = unit.charinfo,
                    job = unit.job,
                    metadata = unit.metadata and { callsign = unit.metadata.callsign } or nil,
                }
            end
        end
    end

    -- Sanitize jobs array
    if call.jobs and type(call.jobs) == 'table' then
        sanitized.jobs = {}
        for _, job in ipairs(call.jobs) do
            sanitized.jobs[#sanitized.jobs + 1] = job
        end
    end

    return sanitized
end

ps.registerCallback(resourceName .. ':server:getRecentDispatches', function(source)
    local src = source
    assert(src, 'Player ID cannot be nil')
    local dispatchResource = Config and Config.Dispatch and Config.Dispatch.Resource or 'ps-dispatch'
    local ok, recentDispatches = pcall(function()
        return exports[dispatchResource] and exports[dispatchResource]:GetDispatchCalls() or {}
    end)
    if not ok then return {} end
    recentDispatches = recentDispatches or {}

    -- Filter by job if configured
    local dispatches = recentDispatches
    if Config and Config.Dispatch and Config.Dispatch.FilterByJob == true then
        local jobName = ps.getJobName(src)
        local jobType = ps.getJobType and ps.getJobType(src) or nil
        if jobName then
            local filtered = {}
            for _, call in ipairs(recentDispatches) do
                if not call.jobs or #call.jobs == 0 then
                    filtered[#filtered + 1] = call
                else
                    local matched = false
                    for _, job in ipairs(call.jobs) do
                        if job == jobName or job == jobType then
                            matched = true
                            break
                        end
                    end
                    if matched then
                        filtered[#filtered + 1] = call
                    end
                end
            end
            dispatches = filtered
        end
    end

    -- Sanitize for serialization
    local result = {}
    for _, call in ipairs(dispatches) do
        local sanitized = sanitizeDispatch(call)
        if sanitized then
            result[#result + 1] = sanitized
        end
    end

    return result
end)

ps.registerCallback(resourceName .. ':server:getUsageMetrics', function(source)
    local src = source
    if not CheckAuth(src) then return {} end

    return Cache.getOrSet('dashboard:usageMetrics', Config.CacheTTL and Config.CacheTTL.UsageMetrics or 60, function()
        -- Use separate queries with pcall to handle missing tables gracefully
        local function safeCount(query, params)
            local ok, result = pcall(MySQL.scalar.await, query, params or {})
            if ok then return tonumber(result) or 0 end
            return 0
        end

        local totalReports = safeCount('SELECT COUNT(*) FROM mdt_reports')
        local reportsLast7 = safeCount('SELECT COUNT(*) FROM mdt_reports WHERE datecreated >= NOW() - INTERVAL 7 DAY')
        local reportsLast30 = safeCount('SELECT COUNT(*) FROM mdt_reports WHERE datecreated >= NOW() - INTERVAL 30 DAY')
        local totalArrests = safeCount('SELECT COUNT(*) FROM mdt_arrests')
        local arrestsLast7 = safeCount('SELECT COUNT(*) FROM mdt_arrests WHERE created_at >= NOW() - INTERVAL 7 DAY')
        local arrestsLast30 = safeCount('SELECT COUNT(*) FROM mdt_arrests WHERE created_at >= NOW() - INTERVAL 30 DAY')
        local activeWarrants = safeCount('SELECT COUNT(*) FROM mdt_reports_warrants WHERE expirydate >= NOW()')

        return {
            totals = {
                reports = totalReports,
                arrests = totalArrests,
                activeWarrants = activeWarrants,
            },
            windows = {
                reportsLast7 = reportsLast7,
                reportsLast30 = reportsLast30,
                arrestsLast7 = arrestsLast7,
                arrestsLast30 = arrestsLast30,
            }
        }
    end)
end)
