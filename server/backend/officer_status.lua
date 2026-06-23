-- ============================================================================
--  officer_status.lua  —  MDT officer availability status (server side)
-- ----------------------------------------------------------------------------
--  Responsibilities:
--    * Lets an on-duty officer set/clear their own availability status
--      (Active/Busy/...), persisted in `mdt_officer_status`.
--    * Broadcasts every change to all online officers of the same domain in
--      real time (mirrors the syncPatrols pattern in tracking.lua), so the
--      Map tab's officer list/markers update immediately without polling.
--    * Exposes GetOfficerStatusSnapshot(domain) so tracking.lua can fold the
--      current status into each bodycam entry returned by getTracking,
--      without tracking.lua needing to know how status is stored.
--
--  Adding a new status:
--    Just append an entry to Config.OfficerStatus.list in config.lua — this
--    file, the client, and the UI all read that list, so nothing else needs
--    to change. Never remove/rename an existing id; officers who saved an
--    old id before it was removed would fall back to Config.OfficerStatus.Default.
--
--  Set MDT_DEBUG = true for verbose console logging while developing.
-- ============================================================================

local resourceName = tostring(GetCurrentResourceName())

-- ─── Tunables ───────────────────────────────────────────────────────────────
local MDT_DEBUG = false -- verbose dev logging; KEEP FALSE on production

local function dbg(...)
    if MDT_DEBUG then print('[MDT:status]', ...) end
end

-- ─── Config-derived lookups ─────────────────────────────────────────────────

local statusList   = (Config.OfficerStatus and Config.OfficerStatus.list) or {}
local defaultStatus = (Config.OfficerStatus and Config.OfficerStatus.Default) or 'active'
local maxNoteLength  = (Config.OfficerStatus and Config.OfficerStatus.MaxNoteLength) or 60
local changeCooldownMs = (Config.OfficerStatus and Config.OfficerStatus.ChangeCooldownMs) or 1500

-- [id] = true, for O(1) validation of incoming status ids.
local validStatusIds = {}
for _, entry in ipairs(statusList) do
    validStatusIds[entry.id] = true
end
if not validStatusIds[defaultStatus] then
    -- Config typo guard: fall back to the first configured status, or 'active'
    -- if the list itself is empty, so the feature never hard-locks on bad config.
    defaultStatus = statusList[1] and statusList[1].id or 'active'
end

-- ─── State ──────────────────────────────────────────────────────────────────
-- In-memory mirror of mdt_officer_status, keyed by citizenid. Loaded on
-- resource start and kept in sync on every write — getTracking reads this,
-- never the DB, so the heavy tracking poll never blocks on a query.
local officerStatus = {}            -- [citizenid] = { status, note, updatedAt, domain }
local changeCooldowns = {}          -- [src] = GetGameTimer() of last change

-- ─── Validation ─────────────────────────────────────────────────────────────

local function isValidStatusId(id)
    return type(id) == 'string' and validStatusIds[id] == true
end

local function sanitizeNote(note)
    if note == nil then return nil end
    if type(note) ~= 'string' then return nil end
    note = note:gsub('^%s+', ''):gsub('%s+$', '')
    if #note == 0 then return nil end
    if #note > maxNoteLength then
        note = note:sub(1, maxNoteLength)
    end
    return note
end

-- ─── Officer info (mirrors tracking.lua's getOfficerInfo) ──────────────────

local _qbCore
local function getQBCore()
    if _qbCore then return _qbCore end
    if exports['qb-core'] then
        _qbCore = exports['qb-core']:GetCoreObject()
    end
    return _qbCore
end

local function getOfficerInfo(src)
    local QBCore = getQBCore()
    if QBCore then
        local player = QBCore.Functions.GetPlayer(src)
        if player then
            local d = player.PlayerData
            return {
                citizenid = d.citizenid,
                name      = d.charinfo.firstname .. ' ' .. d.charinfo.lastname,
                callsign  = d.metadata and d.metadata.callsign or nil,
            }
        end
    elseif ps and ps.getIdentifier then
        return {
            citizenid = ps.getIdentifier(src),
            name      = (ps.getPlayerName and ps.getPlayerName(src)) or GetPlayerName(src) or 'Unknown',
            callsign  = ps.getMetadata and ps.getMetadata(src, 'callsign') or nil,
        }
    end
    return nil
end

-- ─── DB ─────────────────────────────────────────────────────────────────────

local function saveStatusNow(citizenid, entry)
    MySQL.insert(
        "INSERT INTO mdt_officer_status (citizenid, status, note, job_type, updated_at) VALUES (?, ?, ?, ?, NOW()) " ..
        "ON DUPLICATE KEY UPDATE status = VALUES(status), note = VALUES(note), job_type = VALUES(job_type), updated_at = NOW()",
        { citizenid, entry.status, entry.note, entry.domain or 'police' }
    )
end

-- ─── Broadcast ──────────────────────────────────────────────────────────────
-- Mirrors tracking.lua's playersInDomain/doBroadcast pattern so status changes
-- reach every open MDT of the same domain instantly, same as patrol updates.

local function playersInDomain(domain)
    local out = {}
    local QBCore = getQBCore()
    if QBCore then
        for _, player in pairs(QBCore.Functions.GetQBPlayers() or {}) do
            local d = player.PlayerData
            if d and d.job and d.source then
                if GetDomainForJob(d.job.name, d.job.type) == domain then
                    out[#out + 1] = d.source
                end
            end
        end
    elseif ps and ps.getAllPlayers then
        for _, pid in pairs(ps.getAllPlayers() or {}) do
            local jobName = ps.getJobName and ps.getJobName(pid) or nil
            local jobType = ps.getJobType and ps.getJobType(pid) or nil
            if GetDomainForJob(jobName, jobType) == domain then
                out[#out + 1] = pid
            end
        end
    end
    return out
end

-- Broadcasts a single officer's new status to their domain. Deliberately NOT
-- coalesced (unlike broadcastPatrols' plain-mutation path): status changes are
-- infrequent, user-initiated, one-citizen-at-a-time events, so there is no
-- burst to coalesce and the UI should reflect the change with no perceptible
-- delay.
local function broadcastStatus(citizenid, entry)
    local domain = entry.domain or 'police'
    local payload = {
        citizenid = citizenid,
        status    = entry.status,
        note      = entry.note,
        updatedAt = entry.updatedAt,
    }
    for _, src in ipairs(playersInDomain(domain)) do
        TriggerClientEvent(resourceName .. ':client:syncOfficerStatus', src, payload)
    end
end

-- ─── Public accessor for tracking.lua ───────────────────────────────────────
-- Returns { [citizenid] = { status, note, updatedAt } } for one domain. Cheap:
-- pure in-memory filter, no DB hit, safe to call on every getTracking poll.
function GetOfficerStatusSnapshot(domain)
    domain = (domain == 'ems') and 'ems' or 'police'
    local out = {}
    for citizenid, entry in pairs(officerStatus) do
        if (entry.domain or 'police') == domain then
            out[citizenid] = {
                status    = entry.status,
                note      = entry.note,
                updatedAt = entry.updatedAt,
            }
        end
    end
    return out
end

-- ─── Callbacks ──────────────────────────────────────────────────────────────

-- Static status config (ids/labels/colors) — fetched once by the NUI on Map
-- mount so the picker/legend/filter never hardcode status definitions
-- client-side. Cheap and rarely called, so no caching needed.
ps.registerCallback(resourceName .. ':server:getOfficerStatusConfig', function(source)
    if not CheckAuth(source) then return { statuses = {}, default = defaultStatus } end
    return { statuses = statusList, default = defaultStatus }
end)

RegisterNetEvent(resourceName .. ':server:setOfficerStatus', function(statusId, note)
    local src = source
    if not CheckAuth(src) then return end

    local now = GetGameTimer()
    local last = changeCooldowns[src]
    if last and (now - last) < changeCooldownMs then
        return -- silently drop spam clicks; the NUI already disables the control during cooldown
    end

    if not isValidStatusId(statusId) then
        dbg('rejected invalid status id from src', src, tostring(statusId))
        return
    end

    local officer = getOfficerInfo(src)
    if not officer or not officer.citizenid then return end

    changeCooldowns[src] = now

    local cleanNote = sanitizeNote(note)
    local domain = GetMdtDomain(src)
    local previous = officerStatus[officer.citizenid]

    local entry = {
        status    = statusId,
        note      = cleanNote,
        updatedAt = os.time() * 1000, -- ms epoch; client renders relative time from this
        domain    = domain,
    }
    officerStatus[officer.citizenid] = entry
    saveStatusNow(officer.citizenid, entry)
    broadcastStatus(officer.citizenid, entry)

    dbg(('%s set status to "%s"%s'):format(officer.name or officer.citizenid, statusId, cleanNote and (' (' .. cleanNote .. ')') or ''))

    if ps.auditLog then
        ps.auditLog(src, 'officer_status_changed', officer.citizenid, {
            officer_name    = officer.name,
            officer_callsign = officer.callsign,
            officer_id      = officer.citizenid,
            previous_status = previous and previous.status or nil,
            new_status      = statusId,
            note            = cleanNote,
            action_label    = ('%s set status to "%s"%s'):format(
                officer.name or 'Officer', statusId, cleanNote and (' — ' .. cleanNote) or ''
            ),
        })
    end
end)

-- ─── Lifecycle ──────────────────────────────────────────────────────────────

AddEventHandler('onResourceStart', function(res)
    if res ~= resourceName then return end

    local ok, rows = pcall(function()
        return MySQL.query.await(
            "SELECT citizenid, status, note, job_type, UNIX_TIMESTAMP(updated_at) AS updated_at_unix FROM mdt_officer_status"
        )
    end)
    if not ok or type(rows) ~= 'table' then
        print(('^1[MDT]^7 Failed to load officer statuses. Is the `mdt_officer_status` table installed? Error: %s')
            :format(tostring(rows)))
        return
    end

    officerStatus = {}
    for _, row in ipairs(rows) do
        -- Drop any persisted status id that no longer exists in config (e.g. an
        -- id was renamed/removed) instead of surfacing an unrenderable status.
        local statusId = isValidStatusId(row.status) and row.status or defaultStatus
        officerStatus[row.citizenid] = {
            status    = statusId,
            note      = row.note,
            updatedAt = row.updated_at_unix and (row.updated_at_unix * 1000) or (os.time() * 1000),
            domain    = (row.job_type == 'ems') and 'ems' or 'police',
        }
    end
    ps.debug(('^2[MDT]^7 Loaded %d officer status record(s).'):format(#rows))
end)

AddEventHandler('playerDropped', function()
    -- Intentionally NOT clearing status on disconnect: an officer who goes
    -- on a quick reconnect (or crashes) keeps their last status rather than
    -- silently flipping back to Active, which would be misleading to the
    -- rest of the department. Status is cleared explicitly (set back to the
    -- default) by the officer themselves, not by connection state.
    changeCooldowns[source] = nil
end)
