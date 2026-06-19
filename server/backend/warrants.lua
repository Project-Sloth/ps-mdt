local resourceName = tostring(GetCurrentResourceName())

local function validateExpiry(expiry)
    if not expiry then
        return nil
    end
    local asNumber = tonumber(expiry)
    if asNumber then
        return asNumber
    end
    if type(expiry) == 'string' then
        local trimmed = expiry:match('^%s*(.-)%s*$')
        if trimmed and trimmed ~= '' then
            return trimmed
        end
    end
    return nil
end

local function toTimestamp(value)
    if not value then
        return nil
    end
    local numeric = tonumber(value)
    if numeric then
        if numeric > 100000000000 then
            return math.floor(numeric / 1000)
        end
        return numeric
    end
    return nil
end

local function getExpiryDate(value)
    local ts = toTimestamp(value)
    if ts then
        return os.date('%Y-%m-%d %H:%M:%S', ts)
    end
    if type(value) == 'string' and value ~= '' then
        return value
    end
    return nil
end

-- Exposed as a global so the dashboard aggregate (server/backend/dashboard.lua)
-- can reuse it without a second round-trip.
function GetActiveWarrantsData(src)
    local rows = MySQL.query.await([[
        SELECT
            w.reportid,
            w.citizenid,
            w.felonies,
            w.misdemeanors,
            w.infractions,
            w.expirydate,
            JSON_UNQUOTE(JSON_EXTRACT(p.charinfo, '$.firstname')) AS firstname,
            JSON_UNQUOTE(JSON_EXTRACT(p.charinfo, '$.lastname')) AS lastname
        FROM mdt_reports_warrants w
        LEFT JOIN players p ON p.citizenid COLLATE utf8mb4_general_ci = w.citizenid COLLATE utf8mb4_general_ci
        WHERE w.expirydate >= NOW()
        ORDER BY w.expirydate ASC
    ]])

    local results = {}
    for _, row in ipairs(rows or {}) do
        local name = ((row.firstname or '') .. ' ' .. (row.lastname or '')):gsub('^%s+', ''):gsub('%s+$', '')
        if name == '' then
            name = ps.getPlayerNameByIdentifier(row.citizenid) or 'Unknown'
        end
        results[#results + 1] = {
            reportid = row.reportid,
            citizenid = row.citizenid,
            name = name,
            felonies = tonumber(row.felonies) or 0,
            misdemeanors = tonumber(row.misdemeanors) or 0,
            infractions = tonumber(row.infractions) or 0,
            expirydate = row.expirydate,
        }
    end

    return results
end

-- Push the current active-warrants list to all clients so any open MDT
-- live-updates without a manual refresh. The payload is global (identical for
-- every viewer), so a single broadcast is enough; the client relay gates it to
-- LEO players before handing it to the NUI.
function BroadcastActiveWarrants()
    TriggerClientEvent(resourceName .. ':client:updateActiveWarrants', -1, GetActiveWarrantsData())
end

ps.registerCallback(resourceName .. ':server:getActiveWarrants', function(source)
    local src = source
    if not CheckAuth(src) then return {} end
    return GetActiveWarrantsData(src)
end)

ps.registerCallback(resourceName .. ':server:issueWarrant', function(source, data)
    local src = source
    if not CheckAuth(src) then return { success = false, error = 'Unauthorized' } end
    if not CheckPermission(src, 'warrants_issue') then
        return { success = false, error = 'Insufficient permissions' }
    end

    data = data or {}
    local reportId = tonumber(data.reportId)
    local citizenid = data.citizenid
    local expiryValue = validateExpiry(data.expirydate)
    local expiryDate = getExpiryDate(expiryValue)
    if not expiryDate then
        local defaultDays = (Config and Config.Warrants and Config.Warrants.DefaultExpiryDays) or 7
        expiryDate = os.date('%Y-%m-%d %H:%M:%S', os.time() + (defaultDays * 24 * 60 * 60))
    end

    if not reportId or not citizenid then
        return { success = false, error = 'Missing required fields' }
    end

    -- One warrant per report: refuse if this report already has any active
    -- (non-expired) warrant, regardless of which subject it targets.
    local activeForReport = MySQL.single.await('SELECT 1 AS x FROM mdt_reports_warrants WHERE reportid = ? AND expirydate >= NOW() LIMIT 1', { reportId })
    if activeForReport then
        return { success = false, error = 'This report already has an active warrant' }
    end

    local existing = MySQL.single.await('SELECT reportid FROM mdt_reports_warrants WHERE reportid = ? AND citizenid = ?', { reportId, citizenid })
    if existing and existing.reportid then
        return { success = false, error = 'An active warrant already exists for this subject on this report' }
    else
        MySQL.insert.await([[
            INSERT INTO mdt_reports_warrants (reportid, citizenid, felonies, misdemeanors, infractions, expirydate)
            VALUES (?, ?, 0, 0, 0, ?)
        ]], { reportId, citizenid, expiryDate })
    end

    if ps.auditLog then
        ps.auditLog(src, 'warrant_issued', 'warrant', reportId, {
            citizenid = citizenid,
            expirydate = expiryDate
        })
    end

    BroadcastActiveWarrants()
    return { success = true }
end)

ps.registerCallback(resourceName .. ':server:closeWarrant', function(source, data)
    local src = source
    if not CheckAuth(src) then return { success = false, error = 'Unauthorized' } end
    if not CheckPermission(src, 'warrants_close') then
        return { success = false, error = 'Insufficient permissions' }
    end

    data = data or {}
    local reportId = tonumber(data.reportId)
    local citizenid = data.citizenid
    if not reportId or not citizenid then
        return { success = false, error = 'Missing required fields' }
    end

    local updated = MySQL.update.await([[
        UPDATE mdt_reports_warrants
        SET expirydate = NOW()
        WHERE reportid = ? AND citizenid = ?
    ]], { reportId, citizenid })

    if updated and updated > 0 then
        if ps.auditLog then
            ps.auditLog(src, 'warrant_closed', 'warrant', reportId, {
                citizenid = citizenid
            })
        end
        BroadcastActiveWarrants()
        return { success = true }
    end

    return { success = false, error = 'Warrant not found' }
end)