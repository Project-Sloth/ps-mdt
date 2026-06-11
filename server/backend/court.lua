local resourceName = tostring(GetCurrentResourceName())

-- ============================================================================
--  Helpers
-- ============================================================================

local VALID_TYPES = {
    arraignment = true, trial = true, sentencing = true,
    appeal = true, motion = true, hearing = true, other = true,
}
local VALID_CATEGORIES = {
    court = true, training = true, meeting = true, other = true,
}
local VALID_STATUS = {
    scheduled = true, in_session = true, completed = true,
    adjourned = true, cancelled = true,
}
local VALID_ROLES = {
    prosecutor = true, defense = true, officer = true, witness = true,
    judge = true, trainee = true, instructor = true, attendee = true,
}

local function normalizeType(t)
    t = t and tostring(t):lower() or 'trial'
    return VALID_TYPES[t] and t or 'trial'
end

local function normalizeCategory(c)
    c = c and tostring(c):lower() or 'court'
    return VALID_CATEGORIES[c] and c or 'court'
end

-- Court events are gated by court_*; everything else (training/meeting/other)
-- is gated by training_* so instructors can manage trainings without court rights.
local function permForCategory(category, action)
    if normalizeCategory(category) == 'court' then
        return 'court_' .. action
    end
    return 'training_' .. action
end

-- A user may view the calendar if they can view either domain.
local function canViewCalendar(src)
    return CheckPermission(src, 'court_view') or CheckPermission(src, 'training_view')
end

local function normalizeStatus(s)
    s = s and tostring(s):lower() or 'scheduled'
    return VALID_STATUS[s] and s or 'scheduled'
end

local function normalizeRole(r)
    r = r and tostring(r):lower() or 'officer'
    return VALID_ROLES[r] and r or 'officer'
end

local function getOfficerDisplayName(src)
    local callsign = ps.getMetadata(src, 'callsign')
    local name = ps.getPlayerName(src) or 'Unknown'
    if callsign and tostring(callsign) ~= '' then
        return tostring(callsign) .. ' ' .. name
    end
    return name
end

-- ============================================================================
--  Read
-- ============================================================================

-- Fetch hearings within a datetime range (calendar uses this for the visible month)
ps.registerCallback(resourceName .. ':server:getHearings', function(source, payload)
    local src = source
    if not CheckAuth(src) then return {} end
    if not canViewCalendar(src) then return {} end

    payload = payload or {}
    local fromDate = payload.from or os.date('%Y-%m-01 00:00:00')
    local toDate   = payload.to   or os.date('%Y-%m-%d 23:59:59')

    -- Optional category filter (array of category names)
    local catClause, catValues = '', {}
    if type(payload.categories) == 'table' and #payload.categories > 0 then
        local placeholders = {}
        for _, c in ipairs(payload.categories) do
            placeholders[#placeholders + 1] = '?'
            catValues[#catValues + 1] = normalizeCategory(c)
        end
        catClause = ' AND h.category IN (' .. table.concat(placeholders, ',') .. ')'
    end

    local args = { fromDate, toDate }
    for _, v in ipairs(catValues) do args[#args + 1] = v end

    local rows = MySQL.query.await(([[
        SELECT h.*, DATE_FORMAT(h.scheduled_at, '%%Y-%%m-%%d %%H:%%i:%%s') AS scheduled_at,
               c.case_number AS case_number, c.title AS case_title
        FROM mdt_court_hearings h
        LEFT JOIN mdt_cases c ON c.id = h.case_id
        WHERE h.scheduled_at BETWEEN ? AND ?%s
        ORDER BY h.scheduled_at ASC
    ]]):format(catClause), args) or {}

    return rows
end)

-- Fetch a single hearing with its attendees
ps.registerCallback(resourceName .. ':server:getHearing', function(source, payload)
    local src = source
    if not CheckAuth(src) then return { success = false, error = 'Unauthorized' } end
    if not canViewCalendar(src) then return { success = false, error = 'No permission' } end

    payload = payload or {}
    local hearingId = tonumber(payload.hearingId)
    if not hearingId then return { success = false, error = 'Missing hearing id' } end

    local hearing = MySQL.single.await([[
        SELECT h.*, DATE_FORMAT(h.scheduled_at, '%Y-%m-%d %H:%i:%s') AS scheduled_at,
               c.case_number AS case_number, c.title AS case_title
        FROM mdt_court_hearings h
        LEFT JOIN mdt_cases c ON c.id = h.case_id
        WHERE h.id = ?
    ]], { hearingId })

    if not hearing then return { success = false, error = 'Hearing not found' } end

    local attendees = MySQL.query.await([[
        SELECT id, citizenid, display_name, role, notified_at
        FROM mdt_court_attendees WHERE hearing_id = ? ORDER BY role ASC
    ]], { hearingId }) or {}

    return { success = true, data = { hearing = hearing, attendees = attendees } }
end)

-- ============================================================================
--  Create
-- ============================================================================

ps.registerCallback(resourceName .. ':server:createHearing', function(source, payload)
    local src = source
    if not CheckAuth(src) then return { success = false, error = 'Unauthorized' } end

    payload = payload or {}
    local category = normalizeCategory(payload.category)
    if not CheckPermission(src, permForCategory(category, 'create')) then
        return { success = false, error = 'No permission' }
    end
    if not payload.title or tostring(payload.title) == '' then
        return { success = false, error = 'Title is required' }
    end
    if not payload.scheduled_at or tostring(payload.scheduled_at) == '' then
        return { success = false, error = 'Date/time is required' }
    end

    local citizenid = ps.getIdentifier(src)
    if not citizenid then return { success = false, error = 'Missing citizen id' } end

    local hearingId = MySQL.insert.await([[
        INSERT INTO mdt_court_hearings
            (title, category, hearing_type, case_id, warrant_reportid, defendant_cid, defendant_name,
             scheduled_at, duration_minutes, location, judge_cid, judge_name, status, notes,
             created_by, created_by_name)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ]], {
        payload.title,
        category,
        normalizeType(payload.hearing_type),
        tonumber(payload.case_id) or nil,
        tonumber(payload.warrant_reportid) or nil,
        payload.defendant_cid,
        payload.defendant_name,
        payload.scheduled_at,
        tonumber(payload.duration_minutes) or 30,
        payload.location,
        payload.judge_cid,
        payload.judge_name,
        normalizeStatus(payload.status),
        payload.notes,
        citizenid,
        getOfficerDisplayName(src),
    })

    if not hearingId then return { success = false, error = 'Failed to create hearing' } end

    -- Optional initial attendees in the same call
    if type(payload.attendees) == 'table' then
        for _, a in ipairs(payload.attendees) do
            if a.citizenid and tostring(a.citizenid) ~= '' then
                MySQL.insert.await([[
                    INSERT INTO mdt_court_attendees (hearing_id, citizenid, display_name, role)
                    VALUES (?, ?, ?, ?)
                    ON DUPLICATE KEY UPDATE display_name = VALUES(display_name), role = VALUES(role)
                ]], { hearingId, a.citizenid, a.display_name, normalizeRole(a.role) })
            end
        end
    end

    if ps.auditLog then
        ps.auditLog(src, 'court_hearing_created', 'court_hearing', hearingId, {
            title = payload.title, category = category, scheduled_at = payload.scheduled_at,
        })
    end

    return { success = true, hearingId = hearingId }
end)

-- ============================================================================
--  Update (whitelist) + status
-- ============================================================================

ps.registerCallback(resourceName .. ':server:updateHearing', function(source, payload)
    local src = source
    if not CheckAuth(src) then return { success = false, error = 'Unauthorized' } end

    payload = payload or {}
    local hearingId = tonumber(payload.hearingId)
    if not hearingId then return { success = false, error = 'Missing hearing id' } end
    local data = payload.data or {}

    -- Gate by the hearing's CURRENT category
    local existing = MySQL.single.await('SELECT category FROM mdt_court_hearings WHERE id = ?', { hearingId })
    if not existing then return { success = false, error = 'Hearing not found' } end
    if not CheckPermission(src, permForCategory(existing.category, 'edit')) then
        return { success = false, error = 'No permission' }
    end
    -- If moving it to a different category, require rights for the target too
    if data.category ~= nil and normalizeCategory(data.category) ~= existing.category then
        if not CheckPermission(src, permForCategory(data.category, 'create')) then
            return { success = false, error = 'No permission for target category' }
        end
    end

    local updates, values = {}, {}
    local function add(col, val)
        updates[#updates + 1] = col .. ' = ?'
        values[#values + 1] = val
    end

    if data.title ~= nil then add('title', data.title) end
    if data.category ~= nil then add('category', normalizeCategory(data.category)) end
    if data.hearing_type ~= nil then add('hearing_type', normalizeType(data.hearing_type)) end
    if data.case_id ~= nil then add('case_id', tonumber(data.case_id) or nil) end
    if data.warrant_reportid ~= nil then add('warrant_reportid', tonumber(data.warrant_reportid) or nil) end
    if data.defendant_cid ~= nil then add('defendant_cid', data.defendant_cid) end
    if data.defendant_name ~= nil then add('defendant_name', data.defendant_name) end
    if data.scheduled_at ~= nil then add('scheduled_at', data.scheduled_at) end
    if data.duration_minutes ~= nil then add('duration_minutes', tonumber(data.duration_minutes) or 30) end
    if data.location ~= nil then add('location', data.location) end
    if data.judge_cid ~= nil then add('judge_cid', data.judge_cid) end
    if data.judge_name ~= nil then add('judge_name', data.judge_name) end
    if data.status ~= nil then add('status', normalizeStatus(data.status)) end
    if data.notes ~= nil then add('notes', data.notes) end

    if #updates == 0 then return { success = false, error = 'No updates provided' } end

    -- If the time was moved, reset reminder flags so attendees get re-notified
    if data.scheduled_at ~= nil then
        MySQL.update.await('UPDATE mdt_court_attendees SET notified_at = NULL WHERE hearing_id = ?', { hearingId })
    end

    values[#values + 1] = hearingId
    local ok = MySQL.update.await(
        ('UPDATE mdt_court_hearings SET %s WHERE id = ?'):format(table.concat(updates, ', ')),
        values
    )
    if not ok then return { success = false, error = 'Failed to update hearing' } end

    if ps.auditLog then
        ps.auditLog(src, 'court_hearing_updated', 'court_hearing', hearingId, data)
    end

    return { success = true }
end)

-- ============================================================================
--  Delete
-- ============================================================================

ps.registerCallback(resourceName .. ':server:deleteHearing', function(source, payload)
    local src = source
    if not CheckAuth(src) then return { success = false, error = 'Unauthorized' } end

    payload = payload or {}
    local hearingId = tonumber(payload.hearingId)
    if not hearingId then return { success = false, error = 'Missing hearing id' } end

    local existing = MySQL.single.await('SELECT category FROM mdt_court_hearings WHERE id = ?', { hearingId })
    if not existing then return { success = false, error = 'Hearing not found' } end
    if not CheckPermission(src, permForCategory(existing.category, 'delete')) then
        return { success = false, error = 'No permission' }
    end

    -- attendees cascade via FK
    local ok = MySQL.update.await('DELETE FROM mdt_court_hearings WHERE id = ?', { hearingId })
    if not ok then return { success = false, error = 'Failed to delete hearing' } end

    if ps.auditLog then
        ps.auditLog(src, 'court_hearing_deleted', 'court_hearing', hearingId, {})
    end

    return { success = true }
end)

-- ============================================================================
--  Attendees
-- ============================================================================

ps.registerCallback(resourceName .. ':server:addHearingAttendee', function(source, payload)
    local src = source
    if not CheckAuth(src) then return { success = false, error = 'Unauthorized' } end

    payload = payload or {}
    local hearingId = tonumber(payload.hearingId)
    if not hearingId or not payload.citizenid or tostring(payload.citizenid) == '' then
        return { success = false, error = 'Missing data' }
    end

    local existing = MySQL.single.await('SELECT category FROM mdt_court_hearings WHERE id = ?', { hearingId })
    if not existing then return { success = false, error = 'Hearing not found' } end
    if not CheckPermission(src, permForCategory(existing.category, 'edit')) then
        return { success = false, error = 'No permission' }
    end

    local id = MySQL.insert.await([[
        INSERT INTO mdt_court_attendees (hearing_id, citizenid, display_name, role)
        VALUES (?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE display_name = VALUES(display_name), role = VALUES(role)
    ]], { hearingId, payload.citizenid, payload.display_name, normalizeRole(payload.role) })

    if ps.auditLog then
        ps.auditLog(src, 'court_attendee_added', 'court_hearing', hearingId, {
            citizenid = payload.citizenid, role = payload.role,
        })
    end

    return { success = true, id = id }
end)

ps.registerCallback(resourceName .. ':server:removeHearingAttendee', function(source, payload)
    local src = source
    if not CheckAuth(src) then return { success = false, error = 'Unauthorized' } end

    payload = payload or {}
    local attendeeId = tonumber(payload.attendeeId)
    if not attendeeId then return { success = false, error = 'Missing attendee id' } end

    -- Gate by the parent hearing's category
    local row = MySQL.single.await([[
        SELECT h.category FROM mdt_court_attendees a
        JOIN mdt_court_hearings h ON h.id = a.hearing_id
        WHERE a.id = ?
    ]], { attendeeId })
    if row and not CheckPermission(src, permForCategory(row.category, 'edit')) then
        return { success = false, error = 'No permission' }
    end

    local ok = MySQL.update.await('DELETE FROM mdt_court_attendees WHERE id = ?', { attendeeId })
    return { success = ok and true or false }
end)

-- ============================================================================
--  Reminder scheduler
--  Scans once per minute for hearings starting within the lead window whose
--  attendees have not yet been notified. notified_at acts as an idempotency
--  marker so reminders never double-fire and survive resource restarts.
-- ============================================================================

CreateThread(function()
    -- small initial delay so the DB / framework are ready
    Wait(15000)
    while true do
        local lead = (Config and Config.Court and Config.Court.ReminderLeadMinutes) or 15
        local ok, due = pcall(MySQL.query.await, [[
            SELECT a.id AS attendee_id, a.citizenid, h.id AS hearing_id, h.title,
                   h.scheduled_at, h.location, h.hearing_type
            FROM mdt_court_attendees a
            JOIN mdt_court_hearings h ON h.id = a.hearing_id
            WHERE a.notified_at IS NULL
              AND h.status = 'scheduled'
              AND h.scheduled_at >= NOW()
              AND h.scheduled_at <= DATE_ADD(NOW(), INTERVAL ? MINUTE)
        ]], { lead })

        if ok and type(due) == 'table' then
            for _, row in ipairs(due) do
                local notified = false
                if QBCore then
                    local Player = QBCore.Functions.GetPlayerByCitizenId(row.citizenid)
                    if Player and Player.PlayerData and Player.PlayerData.source then
                        local tsrc = Player.PlayerData.source
                        ps.notify(tsrc, ('Court: "%s" in ~%d min @ %s'):format(
                            row.title, lead, row.location or 'TBA'), 'primary')
                        TriggerClientEvent(resourceName .. ':client:courtReminder', tsrc, {
                            hearing_id = row.hearing_id,
                            title = row.title,
                            scheduled_at = tostring(row.scheduled_at),
                            location = row.location,
                            hearing_type = row.hearing_type,
                        })
                        notified = true
                    end
                end
                -- Mark as handled regardless of online state so we don't retry forever.
                -- (Offline officers can see a "missed" indicator when they next open the MDT.)
                MySQL.update.await('UPDATE mdt_court_attendees SET notified_at = NOW() WHERE id = ?', { row.attendee_id })
                if notified then ps.debug(('[court] reminder sent to %s for hearing %s'):format(row.citizenid, row.hearing_id)) end
            end
        end

        Wait(60000) -- 1x per minute
    end
end)
