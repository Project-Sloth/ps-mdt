local resourceName = tostring(GetCurrentResourceName())
local ok, QBCore = pcall(function() return exports['qb-core']:GetCoreObject() end)
if not ok then QBCore = nil end

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

-- Allowed status lifecycle transitions (enforced by setHearingStatus).
-- scheduled -> in_session (live) | cancelled | adjourned
-- in_session -> completed (which deletes the hearing, see Config.Court.AutoStatus)
-- cancelled / adjourned -> scheduled (reopen)
local ALLOWED_TRANSITIONS = {
    scheduled  = { in_session = true, cancelled = true, adjourned = true },
    in_session = { completed = true },
    cancelled  = { scheduled = true },
    adjourned  = { scheduled = true },
    completed  = {},
}

-- A hearing that is live or finished can no longer be edited.
local function isLockedStatus(status)
    return status == 'in_session' or status == 'completed'
end

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

-- The calendar "domain" the caller belongs to. Police and DOJ share the
-- 'police' domain so their calendar stays in sync; EMS is its own 'ems'
-- domain with a completely separate set of events.
local function callerCalendarDomain(src)
    if GetMdtDomain then return GetMdtDomain(src) end
    return 'police'
end

-- EMS never deals with court cases, so the 'court' category is police-only.
local function categoryAllowedForDomain(category, domain)
    if domain == 'ems' and normalizeCategory(category) == 'court' then
        return false
    end
    return true
end

-- A user may view the calendar if they can view either domain.
local function canViewCalendar(src)
    return CheckPermission(src, 'court_view') or CheckPermission(src, 'training_view')
end

-- Validate an optional case_id against mdt_cases to avoid FK insert errors.
-- Returns: resolvedId (number or nil), ok (false only when a non-empty id was given but not found)
local function resolveCaseId(rawCaseId)
    local caseId = tonumber(rawCaseId)
    if not caseId then return nil, true end
    local row = MySQL.single.await('SELECT id FROM mdt_cases WHERE id = ?', { caseId })
    if not row then return nil, false end
    return caseId, true
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
--  lb-phone integration (reminder SMS + invite e-mails)
-- ============================================================================

local function courtCfg()
    return (Config and Config.Court) or {}
end

-- Returns the configured phone resource name only if it is actually running.
local function phoneResource()
    local cfg = courtCfg().Phone
    local res = cfg and cfg.Resource
    if not res or res == '' then return nil end
    if GetResourceState(res) ~= 'started' then return nil end
    return res
end

-- Resolve a player's equipped phone number from their citizenid (works offline).
local function getPhoneNumberFor(citizenid)
    local res = phoneResource()
    if not res or not citizenid then return nil, res end
    local ok, num = pcall(function()
        return exports[res]:GetEquippedPhoneNumber(citizenid)
    end)
    if ok and num and tostring(num) ~= '' then return num, res end
    return nil, res
end

-- Format a "YYYY-MM-DD HH:MM:SS" timestamp according to Config.DateTime.
local function formatScheduled(scheduled_at)
    local s = tostring(scheduled_at or '')
    local y, mo, da, hh, mi = s:match('(%d+)%-(%d+)%-(%d+)%s+(%d+):(%d+)')
    if not y then return s end
    local dt = (Config and Config.DateTime) or {}
    local fmt = dt.DateFormat or 'YYYY-MM-DD'
    local datePart
    if fmt == 'MM-DD-YYYY' then datePart = ('%s/%s/%s'):format(mo, da, y)
    elseif fmt == 'DD-MM-YYYY' then datePart = ('%s.%s.%s'):format(da, mo, y)
    else datePart = ('%s-%s-%s'):format(y, mo, da) end

    local timePart = hh .. ':' .. mi
    if dt.TimeFormat == '12' then
        local h = tonumber(hh) or 0
        local suffix = h >= 12 and 'PM' or 'AM'
        local h12 = h % 12
        if h12 == 0 then h12 = 12 end
        timePart = ('%d:%s %s'):format(h12, mi, suffix)
    end
    return datePart .. ' ' .. timePart
end

-- Send a reminder SMS from the configured court number to one attendee.
local function sendHearingSms(citizenid, body)
    local cfg = courtCfg()
    if not (cfg.Sms and cfg.Sms.enabled) then return false end
    local to, res = getPhoneNumberFor(citizenid)
    if not to then return false end
    local from = (cfg.Phone and cfg.Phone.SmsSenderNumber) or 'COURT'
    local ok = pcall(function()
        exports[res]:SendMessage(from, to, body)
    end)
    return ok and true or false
end

-- Send an invite e-mail to one attendee (resolves their mail address via lb-phone).
local function sendHearingMail(citizenid, subject, message)
    local cfg = courtCfg()
    if not (cfg.Email and cfg.Email.enabled) then return false end
    local number, res = getPhoneNumberFor(citizenid)
    if not number then return false end
    local mok, email = pcall(function() return exports[res]:GetEmailAddress(number) end)
    if not mok or not email or tostring(email) == '' then return false end
    local sender = (cfg.Phone and cfg.Phone.MailSender) or 'Court'
    local sok = pcall(function()
        exports[res]:SendMail({
            to = email,
            sender = sender,
            subject = subject,
            message = message,
        })
    end)
    return sok and true or false
end

-- Body for the lead-time reminder SMS.
local function buildReminderSms(row, lead)
    local lines = {}
    lines[#lines + 1] = ('Reminder: "%s" starts in ~%d min.'):format(row.title or 'Hearing', lead)
    lines[#lines + 1] = 'When: ' .. formatScheduled(row.scheduled_at)
    if row.location and tostring(row.location) ~= '' then
        lines[#lines + 1] = 'Where: ' .. row.location
    end
    return table.concat(lines, '\n')
end

-- Body for the "you have been added" invite e-mail.
local function buildHearingMailBody(h)
    local lines = {}
    lines[#lines + 1] = ('You have been added to: %s'):format(h.title or 'an event')
    lines[#lines + 1] = ''
    lines[#lines + 1] = 'When: ' .. formatScheduled(h.scheduled_at)
    if h.duration_minutes then lines[#lines + 1] = ('Duration: %d min'):format(tonumber(h.duration_minutes) or 30) end
    if h.location and tostring(h.location) ~= '' then lines[#lines + 1] = 'Where: ' .. h.location end
    if h.judge_name and tostring(h.judge_name) ~= '' then lines[#lines + 1] = 'Lead / Judge: ' .. h.judge_name end
    if h.notes and tostring(h.notes) ~= '' then
        lines[#lines + 1] = ''
        lines[#lines + 1] = 'Notes: ' .. h.notes
    end
    lines[#lines + 1] = ''
    lines[#lines + 1] = 'You will receive a reminder shortly before it starts.'
    return table.concat(lines, '\n')
end

-- Fire invite e-mails for a freshly created hearing, off the request thread.
-- Skips entirely when the invite list is larger than the configured cap so a
-- huge meeting never blocks/lags the server (those people still get the SMS).
local function dispatchCreateEmails(hearing, targets)
    local cfg = courtCfg()
    if not (cfg.Email and cfg.Email.enabled) then return end
    if type(targets) ~= 'table' or #targets == 0 then return end

    local maxR = tonumber(cfg.Email.MaxRecipients) or 25
    if #targets > maxR then
        if ps.debug then
            ps.debug(('[court] %d invitees > Email.MaxRecipients (%d); skipping invite e-mails, reminder SMS will still fire')
                :format(#targets, maxR))
        end
        return
    end

    local subject = ('Invitation: %s'):format(hearing.title or 'Event')
    local body = buildHearingMailBody(hearing)
    local delay = tonumber(cfg.Email.SendDelayMs) or 50

    CreateThread(function()
        for _, t in ipairs(targets) do
            if t.citizenid and tostring(t.citizenid) ~= '' then
                sendHearingMail(t.citizenid, subject, body)
                if delay > 0 then Wait(delay) end
            end
        end
    end)
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
    local domain   = callerCalendarDomain(src)

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

    local args = { domain, fromDate, toDate }
    for _, v in ipairs(catValues) do args[#args + 1] = v end

    local rows = MySQL.query.await(([[
        SELECT h.*, DATE_FORMAT(h.scheduled_at, '%%Y-%%m-%%d %%H:%%i:%%s') AS scheduled_at,
               c.case_number AS case_number, c.title AS case_title
        FROM mdt_court_hearings h
        LEFT JOIN mdt_cases c ON c.id = h.case_id
        WHERE h.job_type = ? AND h.scheduled_at BETWEEN ? AND ?%s
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
    -- Don't leak events from the other domain (police/DOJ <-> EMS).
    if hearing.job_type and hearing.job_type ~= callerCalendarDomain(src) then
        return { success = false, error = 'Hearing not found' }
    end

    local attendees = MySQL.query.await([[
        SELECT id, citizenid, display_name, role, notified_at
        FROM mdt_court_attendees WHERE hearing_id = ? ORDER BY role ASC
    ]], { hearingId }) or {}

    return { success = true, data = { hearing = hearing, attendees = attendees } }
end)

-- Hearings whose reminder fired while this officer was offline (missed),
-- surfaced once on the next MDT open. Marks them delivered so they show once.
ps.registerCallback(resourceName .. ':server:getMissedHearings', function(source)
    local src = source
    if not CheckAuth(src) then return {} end
    if not canViewCalendar(src) then return {} end

    local cid = ps.getIdentifier(src)
    if not cid then return {} end

    local rows = MySQL.query.await([[
        SELECT h.id AS hearing_id, h.title, h.category, h.location,
               DATE_FORMAT(h.scheduled_at, '%Y-%m-%d %H:%i') AS scheduled_at
        FROM mdt_court_attendees a
        JOIN mdt_court_hearings h ON h.id = a.hearing_id
        WHERE a.citizenid = ?
          AND a.notified_at IS NOT NULL
          AND a.delivered_at IS NULL
        ORDER BY h.scheduled_at DESC
        LIMIT 15
    ]], { cid }) or {}

    if #rows > 0 then
        MySQL.update.await([[
            UPDATE mdt_court_attendees SET delivered_at = NOW()
            WHERE citizenid = ? AND notified_at IS NOT NULL AND delivered_at IS NULL
        ]], { cid })
    end

    return rows
end)

-- ============================================================================
--  Create
-- ============================================================================

ps.registerCallback(resourceName .. ':server:createHearing', function(source, payload)
    local src = source
    if not CheckAuth(src) then return { success = false, error = 'Unauthorized' } end

    payload = payload or {}
    local category = normalizeCategory(payload.category)
    local domain = callerCalendarDomain(src)
    if not categoryAllowedForDomain(category, domain) then
        return { success = false, error = 'Category not allowed for this department' }
    end
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

    local caseId, caseOk = resolveCaseId(payload.case_id)
    if not caseOk then return { success = false, error = 'Case ID does not exist' } end

    local hearingId = MySQL.insert.await([[
        INSERT INTO mdt_court_hearings
            (title, category, hearing_type, case_id, warrant_reportid, defendant_cid, defendant_name,
             scheduled_at, duration_minutes, location, judge_cid, judge_name, status, notes,
             created_by, created_by_name, job_type)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ]], {
        payload.title,
        category,
        normalizeType(payload.hearing_type),
        caseId,
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
        domain,
    })

    if not hearingId then return { success = false, error = 'Failed to create hearing' } end

    -- Optional initial attendees in the same call
    local inviteTargets = {}
    if type(payload.attendees) == 'table' then
        for _, a in ipairs(payload.attendees) do
            if a.citizenid and tostring(a.citizenid) ~= '' then
                MySQL.insert.await([[
                    INSERT INTO mdt_court_attendees (hearing_id, citizenid, display_name, role)
                    VALUES (?, ?, ?, ?)
                    ON DUPLICATE KEY UPDATE display_name = VALUES(display_name), role = VALUES(role)
                ]], { hearingId, a.citizenid, a.display_name, normalizeRole(a.role) })
                inviteTargets[#inviteTargets + 1] = { citizenid = a.citizenid, display_name = a.display_name }
            end
        end
    end

    -- Feature: e-mail every invited person on creation (capped to avoid lag).
    dispatchCreateEmails({
        title = payload.title,
        scheduled_at = payload.scheduled_at,
        duration_minutes = tonumber(payload.duration_minutes) or 30,
        location = payload.location,
        judge_name = payload.judge_name,
        notes = payload.notes,
    }, inviteTargets)

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
    local existing = MySQL.single.await('SELECT category, status FROM mdt_court_hearings WHERE id = ?', { hearingId })
    if not existing then return { success = false, error = 'Hearing not found' } end
    if not CheckPermission(src, permForCategory(existing.category, 'edit')) then
        return { success = false, error = 'No permission' }
    end
    -- A live or completed hearing is locked — only status actions are allowed.
    if isLockedStatus(existing.status) then
        return { success = false, error = 'Hearing is locked and can no longer be edited' }
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
    if data.case_id ~= nil then
        local caseId, caseOk = resolveCaseId(data.case_id)
        if not caseOk then return { success = false, error = 'Case ID does not exist' } end
        add('case_id', caseId)
    end
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

    local existing = MySQL.single.await('SELECT category, status FROM mdt_court_hearings WHERE id = ?', { hearingId })
    if not existing then return { success = false, error = 'Hearing not found' } end
    if isLockedStatus(existing.status) then
        return { success = false, error = 'Hearing is locked' }
    end
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
--  Status lifecycle (manual start / complete / cancel / adjourn / reopen)
--  Completing a hearing deletes it (configurable via Config.Court.AutoStatus).
-- ============================================================================

ps.registerCallback(resourceName .. ':server:setHearingStatus', function(source, payload)
    local src = source
    if not CheckAuth(src) then return { success = false, error = 'Unauthorized' } end

    payload = payload or {}
    local hearingId = tonumber(payload.hearingId)
    local target = payload.status and normalizeStatus(payload.status) or nil
    if not hearingId or not target then return { success = false, error = 'Missing data' } end

    local existing = MySQL.single.await('SELECT category, status FROM mdt_court_hearings WHERE id = ?', { hearingId })
    if not existing then return { success = false, error = 'Hearing not found' } end
    if not CheckPermission(src, permForCategory(existing.category, 'edit')) then
        return { success = false, error = 'No permission' }
    end

    local allowed = ALLOWED_TRANSITIONS[existing.status] or {}
    if not allowed[target] then return { success = false, error = 'Invalid status transition' } end

    -- in_session -> completed: per design, a finished hearing is removed.
    if target == 'completed' then
        local auto = courtCfg().AutoStatus or {}
        if auto.DeleteOnComplete == false then
            MySQL.update.await('UPDATE mdt_court_hearings SET status = ? WHERE id = ?', { 'completed', hearingId })
            if ps.auditLog then ps.auditLog(src, 'court_hearing_completed', 'court_hearing', hearingId, {}) end
            return { success = true, status = 'completed', deleted = false }
        end
        MySQL.update.await('DELETE FROM mdt_court_hearings WHERE id = ?', { hearingId })
        if ps.auditLog then ps.auditLog(src, 'court_hearing_completed', 'court_hearing', hearingId, { deleted = true }) end
        return { success = true, status = 'completed', deleted = true }
    end

    -- Starting it fresh again clears reminder flags so a re-scheduled run re-notifies.
    if target == 'scheduled' then
        MySQL.update.await('UPDATE mdt_court_attendees SET notified_at = NULL, delivered_at = NULL WHERE hearing_id = ?', { hearingId })
    end

    local ok = MySQL.update.await('UPDATE mdt_court_hearings SET status = ? WHERE id = ?', { target, hearingId })
    if not ok then return { success = false, error = 'Failed to update status' } end

    if ps.auditLog then
        ps.auditLog(src, 'court_hearing_status', 'court_hearing', hearingId, { from = existing.status, to = target })
    end
    return { success = true, status = target }
end)

-- ============================================================================
--  Attendee quick-add groups (Rookies / All Officers / All DOJ / ...)
-- ============================================================================

-- List the configured groups (id + label + the role members get).
ps.registerCallback(resourceName .. ':server:getAttendeeGroups', function(source)
    local src = source
    if not CheckAuth(src) then return {} end
    if not canViewCalendar(src) then return {} end

    local domain = callerCalendarDomain(src)
    local out = {}
    for _, g in ipairs(courtCfg().Groups or {}) do
        if g and g.id and (g.domain or 'police') == domain then
            out[#out + 1] = { id = tostring(g.id), label = g.label or tostring(g.id), role = normalizeRole(g.role) }
        end
    end
    return out
end)

-- Resolve the members of one group into a list of stageable attendees.
ps.registerCallback(resourceName .. ':server:getGroupMembers', function(source, payload)
    local src = source
    if not CheckAuth(src) then return { success = false } end
    if not canViewCalendar(src) then return { success = false, error = 'No permission' } end

    payload = payload or {}
    local gid = payload.groupId and tostring(payload.groupId) or nil
    local domain = callerCalendarDomain(src)

    local group
    for _, g in ipairs(courtCfg().Groups or {}) do
        if g and tostring(g.id) == gid and (g.domain or 'police') == domain then group = g break end
    end
    if not group then return { success = false, error = 'Unknown group' } end

    -- Optional explicit job-name whitelist (takes precedence over jobType).
    local jobSet
    if type(group.jobs) == 'table' and #group.jobs > 0 then
        jobSet = {}
        for _, j in ipairs(group.jobs) do jobSet[tostring(j)] = true end
    end

    local role = normalizeRole(group.role)
    local maxGrade = group.maxGrade ~= nil and tonumber(group.maxGrade) or nil
    local members, seen = {}, {}

    local rows = MySQL.query.await('SELECT citizenid, charinfo, job, metadata FROM players', {}) or {}
    for _, row in ipairs(rows) do
        local cid = row.citizenid
        if cid and not seen[cid] then
            local job = row.job and json.decode(row.job) or {}
            local jobName = job.name and tostring(job.name) or nil
            local jobType = job.type and tostring(job.type) or nil

            local match
            if jobSet then
                match = jobName ~= nil and jobSet[jobName] == true
            elseif group.jobType then
                match = jobType == tostring(group.jobType)
            else
                match = false
            end

            if match and maxGrade ~= nil then
                local lvl = (job.grade and tonumber(job.grade.level)) or 0
                if lvl > maxGrade then match = false end
            end
            if match and group.onlyOnDuty then
                if not job.onduty then match = false end
            end

            if match then
                local ci = row.charinfo and json.decode(row.charinfo) or {}
                local md = row.metadata and json.decode(row.metadata) or {}
                local name = ((ci.firstname or '') .. ' ' .. (ci.lastname or ''))
                name = name:gsub('^%s+', ''):gsub('%s+$', '')
                if name == '' then name = cid end
                local callsign = md.callsign
                if callsign and tostring(callsign) ~= '' and callsign ~= 'NO CALLSIGN' then
                    name = tostring(callsign) .. ' ' .. name
                end
                seen[cid] = true
                members[#members + 1] = { citizenid = cid, display_name = name, role = role }
            end
        end
    end

    return { success = true, members = members, role = role }
end)

-- Bulk-add attendees to an existing hearing (used by group quick-add in edit mode).
ps.registerCallback(resourceName .. ':server:addHearingAttendeesBulk', function(source, payload)
    local src = source
    if not CheckAuth(src) then return { success = false, error = 'Unauthorized' } end

    payload = payload or {}
    local hearingId = tonumber(payload.hearingId)
    local list = payload.attendees
    if not hearingId or type(list) ~= 'table' then return { success = false, error = 'Missing data' } end

    local existing = MySQL.single.await('SELECT category, status FROM mdt_court_hearings WHERE id = ?', { hearingId })
    if not existing then return { success = false, error = 'Hearing not found' } end
    if isLockedStatus(existing.status) then return { success = false, error = 'Hearing is locked' } end
    if not CheckPermission(src, permForCategory(existing.category, 'edit')) then
        return { success = false, error = 'No permission' }
    end

    local added = {}
    for _, a in ipairs(list) do
        if a.citizenid and tostring(a.citizenid) ~= '' then
            local id = MySQL.insert.await([[
                INSERT INTO mdt_court_attendees (hearing_id, citizenid, display_name, role)
                VALUES (?, ?, ?, ?)
                ON DUPLICATE KEY UPDATE display_name = VALUES(display_name), role = VALUES(role)
            ]], { hearingId, a.citizenid, a.display_name, normalizeRole(a.role) })
            added[#added + 1] = {
                id = id, citizenid = a.citizenid,
                display_name = a.display_name, role = normalizeRole(a.role),
            }
        end
    end

    if ps.auditLog then
        ps.auditLog(src, 'court_attendees_bulk_added', 'court_hearing', hearingId, { count = #added })
    end
    return { success = true, added = added }
end)

-- ============================================================================
--  Scheduler
--  Runs once a minute and does two jobs:
--    1) Auto status lifecycle: scheduled -> in_session -> completed(-> delete).
--    2) Reminder SMS: lb-phone SMS to attendees inside the lead window.
--  notified_at is an idempotency marker so reminders never double-fire and
--  survive resource restarts. SMS reaches offline players too (lb-phone stores
--  it), so we mark both notified_at and delivered_at when a reminder is sent.
-- ============================================================================

-- Step 1 — drive the status lifecycle purely off the clock.
local function runStatusTransitions()
    local auto = courtCfg().AutoStatus
    if not (auto and auto.enabled) then return end

    local grace = tonumber(auto.CompleteGraceMinutes) or 0
    -- end = scheduled_at + duration + grace
    local endExpr = 'DATE_ADD(scheduled_at, INTERVAL (COALESCE(duration_minutes, 30) + ?) MINUTE)'

    -- 1a) Anything whose end time has passed is finished -> complete/remove.
    --     Covers in_session hearings and any scheduled ones that were fully missed.
    if auto.DeleteOnComplete == false then
        pcall(MySQL.update.await, ([[
            UPDATE mdt_court_hearings SET status = 'completed'
            WHERE status IN ('scheduled','in_session') AND %s <= NOW()
        ]]):format(endExpr), { grace })
    else
        pcall(MySQL.update.await, ([[
            DELETE FROM mdt_court_hearings
            WHERE status IN ('scheduled','in_session') AND %s <= NOW()
        ]]):format(endExpr), { grace })
    end

    -- 1b) Scheduled hearings that have started (but not yet ended) go live.
    pcall(MySQL.update.await, ([[
        UPDATE mdt_court_hearings SET status = 'in_session'
        WHERE status = 'scheduled'
          AND scheduled_at <= NOW()
          AND %s > NOW()
    ]]):format(endExpr), { grace })
end

-- Step 2 — send reminder SMS to attendees inside the lead window.
local function runReminders()
    local cfg = courtCfg()
    if not (cfg.Sms and cfg.Sms.enabled) then return end
    if not phoneResource() then return end

    local lead = tonumber(cfg.ReminderLeadMinutes) or 15
    local ok, due = pcall(MySQL.query.await, [[
        SELECT a.id AS attendee_id, a.citizenid, h.id AS hearing_id, h.title,
               DATE_FORMAT(h.scheduled_at, '%Y-%m-%d %H:%i:%s') AS scheduled_at,
               h.location, h.hearing_type
        FROM mdt_court_attendees a
        JOIN mdt_court_hearings h ON h.id = a.hearing_id
        WHERE a.notified_at IS NULL
          AND h.status = 'scheduled'
          AND h.scheduled_at >= NOW()
          AND h.scheduled_at <= DATE_ADD(NOW(), INTERVAL ? MINUTE)
    ]], { lead })
    if not ok or type(due) ~= 'table' then return end

    local delay = tonumber(cfg.Sms.SendDelayMs) or 25
    for _, row in ipairs(due) do
        local sent = sendHearingSms(row.citizenid, buildReminderSms(row, lead))
        -- Mark handled regardless of send outcome so we never retry forever.
        MySQL.update.await(
            'UPDATE mdt_court_attendees SET notified_at = NOW(), delivered_at = NOW() WHERE id = ?',
            { row.attendee_id }
        )
        if sent and ps.debug then
            ps.debug(('[court] reminder SMS sent to %s for hearing %s'):format(row.citizenid, row.hearing_id))
        end
        if delay > 0 then Wait(delay) end
    end
end

CreateThread(function()
    Wait(15000) -- let the DB / framework settle on boot
    while true do
        pcall(runStatusTransitions)
        pcall(runReminders)
        Wait(60000) -- once per minute
    end
end)