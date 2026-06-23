-- ============================================================================
--  server_patrols.lua  —  MDT patrol & live tracking (server side)
-- ----------------------------------------------------------------------------
--  Responsibilities:
--    * Live officer/vehicle tracking served to the map NUI (getTracking).
--    * Patrol CRUD + ordering + zone storage, persisted in `mdt_patrols`.
--    * Audit logging of every patrol mutation via ps.auditLog.
--
--  Performance notes for future devs:
--    * getTracking is polled by EVERY open MDT (~every 4.5s in the NUI). The
--      result is cached for TRACKING_CACHE_TTL ms so the heavy player/entity
--      scan runs at most once per TTL no matter how many MDTs are open. Never
--      call getAllTrackers() directly from the callback — use getTrackingSnapshot().
--    * vehicleCache holds recently-parked police vehicles. Entries self-expire
--      after VEHICLE_CACHE_TTL so ghost markers disappear even when the
--      'entityRemoved' event never fires (common when entities get culled).
--      Cache-served vehicles carry `cached = true` so the NUI can dim them.
--    * DB writes for frequent mutations (assign/remove) are debounced
--      (SAVE_DEBOUNCE_MS) and coalesced per patrol. Structural changes
--      (create/rename/zone/delete) are written immediately so a crash can't
--      lose them.
--    * broadcastPatrols coalesces plain broadcasts to one per frame. Action
--      broadcasts (assigned/removed) bypass coalescing because the NUI needs
--      the flash hint immediately.
--
--  Set MDT_DEBUG = true for verbose console logging while developing.
-- ============================================================================

local resourceName = tostring(GetCurrentResourceName())

-- ─── Tunables ───────────────────────────────────────────────────────────────
local MDT_DEBUG           = false   -- verbose dev logging; KEEP FALSE on production (log spam)
local TRACKING_CACHE_TTL  = 2000    -- ms — shared tracking snapshot lifetime
local VEHICLE_CACHE_TTL   = 600000  -- ms — parked-vehicle cache entry lifetime (10 min)
local SAVE_DEBOUNCE_MS    = 1000    -- ms — coalesce window for debounced patrol saves

-- ─── State ──────────────────────────────────────────────────────────────────
local vehicleCache = {}             -- [plate] = { plate, coords, heading, _ts }
local cacheVehicleCooldowns = {}    -- [src]   = os.time() of last cacheVehicle event
local patrols = {}                  -- [id]    = patrol
local patrolOrder = {}              -- ordered list of patrol ids
local trackingCache = {
    police = { vehicles = {}, bodycams = {}, ts = 0 },
    ems    = { vehicles = {}, bodycams = {}, ts = 0 },
}

-- ─── Tiny helpers ─────────────────────────────────────────────────────────

-- Gated dev logger. No-op unless MDT_DEBUG is on, so it's free in production.
local function dbg(...)
    if MDT_DEBUG then print('[MDT]', ...) end
end

-- Cache the QBCore object once instead of crossing the export boundary on
-- every call. Returns nil on non-QB frameworks (then the `ps`/ESX path is used).
local _qbCore
local function getQBCore()
    if _qbCore then return _qbCore end
    if exports['qb-core'] then
        _qbCore = exports['qb-core']:GetCoreObject()
    end
    return _qbCore
end

-- ─── Validation ─────────────────────────────────────────────────────────────

local function isValidPatrolId(id)
    return type(id) == "string" and #id > 0 and #id <= 64
end
local function isValidColor(color)
    return type(color) == "string" and color:match("^#%x%x%x%x%x%x$")
end
local function isValidName(name)
    return type(name) == "string" and #name > 0 and #name <= 64
end
local function isValidCitizenId(cid)
    return type(cid) == "string" and #cid > 0 and #cid <= 64
end

-- A caller may only touch patrols that belong to their own domain
-- (police/DOJ on one side, EMS on the other).
local function patrolDomainOK(src, patrol)
    if not patrol then return false end
    return (patrol.domain or 'police') == GetMdtDomain(src)
end

-- Validate zone_points: array of {x, y} pairs, max 64 points
local function isValidZonePoints(points)
    if points == nil then return true end -- nil = no zone, valid
    if type(points) ~= "table" then return false end
    if #points > 64 then return false end
    for _, pt in ipairs(points) do
        if type(pt) ~= "table" then return false end
        if type(pt.x) ~= "number" or type(pt.y) ~= "number" then return false end
        if pt.x < -10000 or pt.x > 10000 or pt.y < -10000 or pt.y > 10000 then return false end
    end
    return true
end

-- ─── Audit helpers ────────────────────────────────────────────────────────

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
                rank      = d.job and d.job.grade and d.job.grade.name or nil,
                job       = d.job and d.job.name or nil,
            }
        end
    elseif ps and ps.getIdentifier then
        local name = (ps.getPlayerName and ps.getPlayerName(src)) or GetPlayerName(src) or 'Unknown'
        return {
            citizenid = ps.getIdentifier(src),
            name      = name,
            callsign  = ps.getMetadata and ps.getMetadata(src, 'callsign') or nil,
            rank      = ps.getJobGradeName and ps.getJobGradeName(src) or nil,
            job       = ps.getJobName and ps.getJobName(src) or nil,
        }
    end
    return { name = GetPlayerName(src) or ('Player #' .. src) }
end

-- Resolve a citizenid -> "Firstname Lastname" without scanning every online
-- player. GetPlayerByCitizenId is a direct lookup on QBCore.
local function getNameByCitizenId(citizenId)
    local QBCore = getQBCore()
    if QBCore and QBCore.Functions.GetPlayerByCitizenId then
        local p = QBCore.Functions.GetPlayerByCitizenId(citizenId)
        if p and p.PlayerData and p.PlayerData.charinfo then
            return p.PlayerData.charinfo.firstname .. ' ' .. p.PlayerData.charinfo.lastname
        end
    end
    return citizenId
end

local function auditPatrol(src, action, patrolId, extra)
    if not ps.auditLog then return end
    local officer = getOfficerInfo(src)
    local data = {
        officer_name     = officer.name,
        officer_callsign = officer.callsign,
        officer_rank     = officer.rank,
        officer_id       = officer.citizenid,
    }
    if extra then
        for k, v in pairs(extra) do data[k] = v end
    end
    ps.auditLog(src, action, 'mdt_patrol', patrolId or 'none', data)
end

-- ─── DB ─────────────────────────────────────────────────────────────────────

-- Immediate write. Used directly for structural changes; the debounced
-- savePatrol() below funnels frequent membership writes through this.
local function savePatrolNow(patrol)
    if not patrol then return end
    MySQL.insert(
        "INSERT INTO mdt_patrols (id, name, color, member_ids, sort_order, zone_points, job_type) VALUES (?, ?, ?, ?, ?, ?, ?) " ..
        "ON DUPLICATE KEY UPDATE name = VALUES(name), color = VALUES(color), " ..
        "member_ids = VALUES(member_ids), sort_order = VALUES(sort_order), zone_points = VALUES(zone_points), job_type = VALUES(job_type)",
        {
            patrol.id,
            patrol.name,
            patrol.color,
            json.encode(patrol.memberIds),
            patrol.sortOrder or 0,
            patrol.zonePoints and json.encode(patrol.zonePoints) or nil,
            patrol.domain or 'police',
        }
    )
end

-- Debounced save: coalesces rapid writes for the same patrol into a single DB
-- write after SAVE_DEBOUNCE_MS. Heavy assign/remove churn no longer hits the DB
-- on every click. Always references the live patrol table, so the flush writes
-- the latest state. delete cancels any pending save (see deletePatrol).
local pendingSaves = {}     -- [id] = patrol
local saveTimerArmed = false

local function flushSaves()
    saveTimerArmed = false
    for id, patrol in pairs(pendingSaves) do
        pendingSaves[id] = nil
        savePatrolNow(patrol)
    end
end

local function savePatrol(patrol)
    if not patrol then return end
    pendingSaves[patrol.id] = patrol
    if not saveTimerArmed then
        saveTimerArmed = true
        SetTimeout(SAVE_DEBOUNCE_MS, flushSaves)
    end
end

local function deletePatrolFromDB(id)
    MySQL.execute("DELETE FROM mdt_patrols WHERE id = ?", { id })
end

local function saveOrder()
    for i, id in ipairs(patrolOrder) do
        if patrols[id] then
            patrols[id].sortOrder = i
            MySQL.execute("UPDATE mdt_patrols SET sort_order = ? WHERE id = ?", { i, id })
        end
    end
end

-- ─── Broadcast ──────────────────────────────────────────────────────────────

-- Online player sources belonging to a given MDT domain (police/DOJ vs ems).
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

-- Ordered patrol list filtered to a single domain.
local function orderedPatrolsForDomain(domain)
    local ordered = {}
    for _, id in ipairs(patrolOrder) do
        local p = patrols[id]
        if p and (p.domain or 'police') == domain then
            ordered[#ordered + 1] = p
        end
    end
    return ordered
end

local function doBroadcast(action, citizenid)
    -- Each domain only receives its own patrols, so EMS never sees police
    -- patrols/zones and vice versa.
    for _, domain in ipairs({ 'police', 'ems' }) do
        local ordered = orderedPatrolsForDomain(domain)
        local targets = playersInDomain(domain)
        for _, src in ipairs(targets) do
            TriggerClientEvent(resourceName .. ":client:syncPatrols", src, ordered, action, citizenid)
        end
    end
end

-- Plain broadcasts (create/delete/rename/reorder/zone/disconnect) are coalesced
-- to one per frame so a burst of mutations doesn't fan the full list out to
-- every client multiple times. Action broadcasts (assigned/removed) carry a
-- flash hint the NUI needs, so they go out immediately.
local broadcastScheduled = false
local function broadcastPatrols(action, citizenid)
    if action then
        doBroadcast(action, citizenid)
        return
    end
    if broadcastScheduled then return end
    broadcastScheduled = true
    SetTimeout(0, function()
        broadcastScheduled = false
        doBroadcast()
    end)
end

-- ─── Tracking ─────────────────────────────────────────────────────────────

-- HEAVY: scans all on-duty players of the given domain + their vehicles. Do not
-- call this per client request — it's wrapped by getTrackingSnapshot() which caches it.
local function getAllTrackers(matchFn, domain)
    matchFn = matchFn or IsPoliceJob
    domain = domain or 'police'
    local vehicles = {}
    local bodycams = {}
    local seenVehicles = {}
    local now = GetGameTimer()

    local QBCore = getQBCore()
    if QBCore then
        local players = QBCore.Functions.GetQBPlayers() or {}

        for _, player in pairs(players) do
            local data = player.PlayerData
            if not data or not data.job or not data.job.onduty then goto continue end
            if not matchFn(data.job.name, data.job.type) then goto continue end

            local src = data.source
            local ped = GetPlayerPed(src)
            if not ped or ped == 0 then goto continue end

            local coords = GetEntityCoords(ped)
            local veh = GetVehiclePedIsIn(ped, false)
            bodycams[#bodycams + 1] = {
                citizenid = data.citizenid,
                name      = data.charinfo.firstname .. ' ' .. data.charinfo.lastname,
                callsign  = data.metadata and data.metadata.callsign or nil,
                rank      = data.job.grade and data.job.grade.name or 'Officer',
                coords    = { x = coords.x, y = coords.y, z = coords.z },
                heading   = GetEntityHeading(ped),
                inVehicle = veh and veh ~= 0,
            }

            if veh and veh ~= 0 and not seenVehicles[veh] then
                seenVehicles[veh] = true
                local vCoords  = GetEntityCoords(veh)
                local vHeading = GetEntityHeading(veh)
                local plate    = GetVehicleNumberPlateText(veh):gsub('%s+', '')
                local coordsTbl = { x = vCoords.x, y = vCoords.y, z = vCoords.z }
                vehicles[#vehicles + 1] = { plate = plate, coords = coordsTbl, heading = vHeading }
                vehicleCache[plate]     = { plate = plate, coords = coordsTbl, heading = vHeading, _ts = now }
            end
            ::continue::
        end

    elseif ps and ps.getAllPlayers then
        local playerList = ps.getAllPlayers() or {}
        for _, playerId in pairs(playerList) do
            if not (ps.getJobDuty and ps.getJobDuty(playerId)) then goto continue end
            local jobName = ps.getJobName and ps.getJobName(playerId) or nil
            local jobType = ps.getJobType and ps.getJobType(playerId) or nil
            if not matchFn(jobName, jobType) then goto continue end

            local ped = GetPlayerPed(playerId)
            if not ped or ped == 0 then goto continue end

            local coords = GetEntityCoords(ped)
            local veh = GetVehiclePedIsIn(ped, false)
            bodycams[#bodycams + 1] = {
                citizenid = ps.getIdentifier and ps.getIdentifier(playerId) or nil,
                name      = (ps.getPlayerName and ps.getPlayerName(playerId)) or GetPlayerName(playerId) or 'Unknown',
                callsign  = ps.getMetadata and ps.getMetadata(playerId, 'callsign') or nil,
                rank      = ps.getJobGradeName and ps.getJobGradeName(playerId) or 'Officer',
                coords    = { x = coords.x, y = coords.y, z = coords.z },
                heading   = GetEntityHeading(ped),
                inVehicle = veh and veh ~= 0,
            }

            if veh and veh ~= 0 and not seenVehicles[veh] then
                seenVehicles[veh] = true
                local vCoords  = GetEntityCoords(veh)
                local vHeading = GetEntityHeading(veh)
                local plate    = GetVehicleNumberPlateText(veh):gsub('%s+', '')
                local coordsTbl = { x = vCoords.x, y = vCoords.y, z = vCoords.z }
                vehicles[#vehicles + 1] = { plate = plate, coords = coordsTbl, heading = vHeading }
                vehicleCache[plate]     = { plate = plate, coords = coordsTbl, heading = vHeading, _ts = now }
            end
            ::continue::
        end
    end

    -- Merge in cached (parked / recently-left) police vehicles that weren't
    -- seen live this pass. The vehicle cache is police-only (populated by the
    -- police-gated cacheVehicle event), so EMS snapshots skip it entirely.
    -- Stale entries are pruned here so ghost markers vanish after
    -- VEHICLE_CACHE_TTL even if 'entityRemoved' never fires. These carry
    -- `cached = true` so the NUI can render them dimmed ("last known position").
    if domain == 'police' then
        local seenPlates = {}
        for _, v in ipairs(vehicles) do seenPlates[v.plate] = true end
        for plate, cacheData in pairs(vehicleCache) do
            if (now - (cacheData._ts or 0)) > VEHICLE_CACHE_TTL then
                vehicleCache[plate] = nil
            elseif not seenPlates[plate] then
                vehicles[#vehicles + 1] = {
                    plate   = cacheData.plate,
                    coords  = cacheData.coords,
                    heading = cacheData.heading,
                    cached  = true,
                }
                seenPlates[plate] = true
            end
        end
    end

    return vehicles, bodycams
end

-- Returns a shared, throttled snapshot for one domain. With N MDTs open the
-- expensive scan runs at most once per TRACKING_CACHE_TTL per domain instead of
-- N times per poll cycle.
local function getTrackingSnapshot(domain)
    domain = (domain == 'ems') and 'ems' or 'police'
    local cache = trackingCache[domain]
    local now = GetGameTimer()
    if cache.ts ~= 0 and (now - cache.ts) < TRACKING_CACHE_TTL then
        return cache
    end
    local matchFn = (domain == 'ems') and IsEmsJob or IsPoliceJob
    local vehicles, bodycams = getAllTrackers(matchFn, domain)

    -- Fold each officer's current availability status into their bodycam
    -- entry. GetOfficerStatusSnapshot is defined in officer_status.lua and is
    -- a cheap in-memory lookup (no DB hit), so this adds no measurable cost to
    -- the tracking poll. Guarded with a global nil-check so tracking.lua keeps
    -- working standalone even if officer_status.lua is ever removed/disabled.
    if GetOfficerStatusSnapshot then
        local statuses = GetOfficerStatusSnapshot(domain)
        for _, bc in ipairs(bodycams) do
            local s = bc.citizenid and statuses[bc.citizenid]
            if s then
                bc.status          = s.status
                bc.statusNote      = s.note
                bc.statusUpdatedAt = s.updatedAt
            end
        end
    end

    cache.vehicles = vehicles
    cache.bodycams = bodycams
    cache.ts = now
    return cache
end

ps.registerCallback(resourceName .. ':server:getTracking', function(source)
    if not CheckAuth(source) then
        return { vehicles = {}, bodycams = {} }
    end
    -- EMS see EMS units; police/DOJ see police units.
    local domain = GetMdtDomain(source)
    local snap = getTrackingSnapshot(domain)
    return { vehicles = snap.vehicles, bodycams = snap.bodycams }
end)

RegisterNetEvent(resourceName .. ':server:cacheVehicle', function(plate, coords, heading)
    local src = source
    -- Defense in depth: only authorised, on-duty police may inject cache markers.
    if not CheckAuth(src) then return end
    if type(plate) ~= 'string' or #plate == 0 or #plate > 8 then return end
    if type(coords) ~= 'table' or type(coords.x) ~= 'number' or type(coords.y) ~= 'number' or type(coords.z) ~= 'number' then return end
    if type(heading) ~= 'number' or heading < 0 or heading > 360 then return end
    if coords.x < -4000 or coords.x > 4000 or coords.y < -4000 or coords.y > 8000 then return end

    local nowSec = os.time()
    if cacheVehicleCooldowns[src] and nowSec - cacheVehicleCooldowns[src] < 5 then return end
    cacheVehicleCooldowns[src] = nowSec

    -- Per-framework duty/police check (QB path and ps/ESX path).
    local QBCore = getQBCore()
    if QBCore then
        local player = QBCore.Functions.GetPlayer(src)
        if not player then return end
        local job = player.PlayerData.job
        if not job or not job.onduty or not IsPoliceJob(job.name, job.type) then return end
    elseif ps and ps.getJobName then
        if not (ps.getJobDuty and ps.getJobDuty(src)) then return end
        local jobName = ps.getJobName(src)
        local jobType = ps.getJobType and ps.getJobType(src) or nil
        if not IsPoliceJob(jobName, jobType) then return end
    end

    vehicleCache[plate] = {
        plate = plate,
        coords = { x = coords.x, y = coords.y, z = coords.z },
        heading = heading,
        _ts = GetGameTimer(),
    }
end)

RegisterNetEvent('baseevents:leftVehicle', function(vehicle, seat, model, netId)
    local src = source
    if not CheckAuth(src) then return end
    local veh = NetworkGetEntityFromNetworkId(netId)
    if not veh or veh == 0 then return end
    local coords = GetEntityCoords(veh)
    local heading = GetEntityHeading(veh)
    local plate = GetVehicleNumberPlateText(veh):gsub('%s+', '')
    if not plate or #plate == 0 then return end
    TriggerClientEvent(resourceName .. ':client:checkVehicleClass', src, netId, plate,
        { x = coords.x, y = coords.y, z = coords.z }, heading)
end)

AddEventHandler('entityRemoved', function(entity)
    if GetEntityType(entity) ~= 2 then return end
    local plate = GetVehicleNumberPlateText(entity)
    if not plate or plate == '' then return end
    plate = plate:gsub('%s+', '')
    vehicleCache[plate] = nil
end)

-- ─── Patrols ──────────────────────────────────────────────────────────────

ps.registerCallback(resourceName .. ":server:getPatrols", function(source)
    local src = source
    if not CheckAuth(src) then return {} end
    local domain = GetMdtDomain(src)
    local ordered = {}
    for _, id in ipairs(patrolOrder) do
        local p = patrols[id]
        if p and (p.domain or 'police') == domain then
            ordered[#ordered + 1] = p
        end
    end
    return ordered
end)

RegisterNetEvent(resourceName .. ":server:createPatrol", function(id, name, color)
    local src = source
    if not CheckAuth(src) then return end
    if not isValidPatrolId(id) or not isValidName(name) or not isValidColor(color) then return end
    if patrols[id] then return end

    local sortOrder = #patrolOrder + 1
    patrols[id] = { id = id, name = name, color = color, memberIds = {}, zonePoints = nil, sortOrder = sortOrder, domain = GetMdtDomain(src) }
    patrolOrder[#patrolOrder + 1] = id
    broadcastPatrols()
    savePatrolNow(patrols[id]) -- structural change → write immediately
    dbg(('patrol created: "%s" (%s)'):format(name, id))
    auditPatrol(src, 'patrol_created', id, {
        patrol_name  = name,
        patrol_color = color,
        action_label = ('Created patrol "%s"'):format(name),
    })
end)

RegisterNetEvent(resourceName .. ":server:deletePatrol", function(id)
    local src = source
    if not CheckAuth(src) then return end
    if not isValidPatrolId(id) then return end
    if not patrols[id] then return end
    if not patrolDomainOK(src, patrols[id]) then return end

    -- Capture the name BEFORE removing the entry (previous code read it after
    -- nil-ing patrols[id], so the audit log always showed the raw id).
    local deletedName = patrols[id].name or id

    pendingSaves[id] = nil -- cancel any debounced save so it can't re-insert the row
    patrols[id] = nil
    for i = #patrolOrder, 1, -1 do
        if patrolOrder[i] == id then
            table.remove(patrolOrder, i)
            break
        end
    end
    deletePatrolFromDB(id)
    saveOrder()
    broadcastPatrols()
    dbg(('patrol deleted: "%s" (%s)'):format(deletedName, id))
    auditPatrol(src, 'patrol_deleted', id, {
        patrol_name  = deletedName,
        action_label = ('Deleted patrol "%s"'):format(deletedName),
    })
end)

RegisterNetEvent(resourceName .. ":server:renamePatrol", function(id, newName)
    local src = source
    if not CheckAuth(src) then return end
    if not isValidPatrolId(id) or not isValidName(newName) then return end
    if not patrols[id] then return end
    if not patrolDomainOK(src, patrols[id]) then return end

    local oldName = patrols[id].name
    patrols[id].name = newName
    broadcastPatrols()
    savePatrolNow(patrols[id]) -- structural change → write immediately
    dbg(('patrol renamed: "%s" -> "%s"'):format(oldName, newName))
    auditPatrol(src, 'patrol_renamed', id, {
        patrol_old_name = oldName,
        patrol_new_name = newName,
        action_label    = ('Renamed patrol "%s" → "%s"'):format(oldName, newName),
    })
end)

-- ─── Zone Points ────────────────────────────────────────────────────────────
-- Client sends updated zone_points for a patrol after drawing on the map.
-- points = array of { x, y } in GTA world coordinates, or nil to clear zone.
RegisterNetEvent(resourceName .. ":server:setPatrolZone", function(id, points)
    local src = source
    if not CheckAuth(src) then return end
    if not isValidPatrolId(id) then return end
    if not patrols[id] then return end
    if not patrolDomainOK(src, patrols[id]) then return end
    if not isValidZonePoints(points) then return end

    -- nil clears the zone; fewer than 3 points also clears it
    local hadZone = patrols[id].zonePoints ~= nil
    patrols[id].zonePoints = (points and #points >= 3) and points or nil
    broadcastPatrols()
    savePatrolNow(patrols[id]) -- zone data is precious → write immediately
    local zoneAction = patrols[id].zonePoints
        and (hadZone and 'patrol_zone_updated' or 'patrol_zone_created')
        or  'patrol_zone_cleared'
    local pts = patrols[id].zonePoints and #patrols[id].zonePoints or 0
    local label = patrols[id].zonePoints
        and ('Drew zone for patrol "%s" (%d points)'):format(patrols[id].name, pts)
        or  ('Cleared zone for patrol "%s"'):format(patrols[id].name)
    dbg(label)
    auditPatrol(src, zoneAction, id, {
        patrol_name  = patrols[id].name,
        point_count  = pts,
        action_label = label,
    })
end)

-- ─── Order / Assign ───────────────────────────────────────────────────────

RegisterNetEvent(resourceName .. ":server:reorderPatrols", function(ids)
    local src = source
    if not CheckAuth(src) then return end
    if type(ids) ~= "table" then return end

    local seen = {}
    local newOrder = {}
    for _, id in ipairs(ids) do
        if isValidPatrolId(id) and patrols[id] and patrolDomainOK(src, patrols[id]) and not seen[id] then
            seen[id] = true
            newOrder[#newOrder + 1] = id
        end
    end
    for _, id in ipairs(patrolOrder) do
        if not seen[id] then
            newOrder[#newOrder + 1] = id
        end
    end

    patrolOrder = newOrder
    saveOrder()
    broadcastPatrols()
    local nameOrder = {}
    for _, pid in ipairs(newOrder) do
        nameOrder[#nameOrder + 1] = patrols[pid] and patrols[pid].name or pid
    end
    dbg('patrols reordered: ' .. table.concat(nameOrder, ' -> '))
    -- NOTE: previous code passed `extra` as a 5th arg (after a nil), so it was
    -- silently dropped. auditPatrol is (src, action, patrolId, extra).
    auditPatrol(src, 'patrols_reordered', 'order', {
        new_order    = table.concat(nameOrder, ' → '),
        action_label = 'Reordered patrols: ' .. table.concat(nameOrder, ' → '),
    })
end)

RegisterNetEvent(resourceName .. ":server:assignOfficer", function(patrolId, citizenId)
    local src = source
    if not CheckAuth(src) then return end
    if not isValidPatrolId(patrolId) or not isValidCitizenId(citizenId) then return end
    if not patrols[patrolId] then return end
    if not patrolDomainOK(src, patrols[patrolId]) then return end

    -- Remove from any other patrol in the same domain before re-assigning.
    for _, patrol in pairs(patrols) do
        if patrolDomainOK(src, patrol) then
            for i = #patrol.memberIds, 1, -1 do
                if patrol.memberIds[i] == citizenId then
                    table.remove(patrol.memberIds, i)
                end
            end
        end
    end
    table.insert(patrols[patrolId].memberIds, citizenId)
    broadcastPatrols("assigned", citizenId)
    savePatrol(patrols[patrolId]) -- frequent mutation → debounced

    local assignedName = getNameByCitizenId(citizenId)
    dbg(('assigned %s to "%s"'):format(assignedName, patrols[patrolId].name))
    auditPatrol(src, 'patrol_officer_assigned', patrolId, {
        patrol_name   = patrols[patrolId].name,
        assigned_name = assignedName,
        assigned_id   = citizenId,
        action_label  = ('Assigned %s to patrol "%s"'):format(assignedName, patrols[patrolId].name),
    })
end)

RegisterNetEvent(resourceName .. ":server:removeFromPatrol", function(citizenId)
    local src = source
    if not CheckAuth(src) then return end
    if not isValidCitizenId(citizenId) then return end

    -- Find which patrol the officer belongs to BEFORE removal (for the audit log)
    local removedFromPatrol = 'unknown'
    for _, patrol in pairs(patrols) do
        if patrolDomainOK(src, patrol) then
            for _, mid in ipairs(patrol.memberIds) do
                if mid == citizenId then removedFromPatrol = patrol.name; break end
            end
        end
    end
    for _, patrol in pairs(patrols) do
        if patrolDomainOK(src, patrol) then
            for i = #patrol.memberIds, 1, -1 do
                if patrol.memberIds[i] == citizenId then
                    table.remove(patrol.memberIds, i)
                    savePatrol(patrol) -- frequent mutation → debounced
                end
            end
        end
    end
    broadcastPatrols("removed", citizenId)
    -- Only audit if the officer was actually found in a patrol
    if removedFromPatrol ~= 'unknown' then
        dbg(('removed %s from "%s"'):format(citizenId, removedFromPatrol))
        auditPatrol(src, 'patrol_officer_removed', citizenId, {
            removed_id   = citizenId,
            removed_from = removedFromPatrol,
            action_label = ('Removed officer from patrol "%s"'):format(removedFromPatrol),
        })
    end
end)

AddEventHandler("playerDropped", function()
    local src = source
    cacheVehicleCooldowns[src] = nil

    local citizenId = nil
    local officerName = GetPlayerName(src) or ('Player #' .. src)

    local QBCore = getQBCore()
    if QBCore then
        local player = QBCore.Functions.GetPlayer(src)
        if player then
            citizenId  = player.PlayerData.citizenid
            officerName = player.PlayerData.charinfo.firstname .. ' ' .. player.PlayerData.charinfo.lastname
        end
    elseif ps and ps.getIdentifier then
        citizenId   = ps.getIdentifier(src)
        officerName = (ps.getPlayerName and ps.getPlayerName(src)) or officerName
    end

    if not citizenId then return end

    -- Find patrol membership BEFORE removal so we can log it
    local removedFromPatrol = nil
    local removedFromId     = nil
    for pid, patrol in pairs(patrols) do
        for _, mid in ipairs(patrol.memberIds) do
            if mid == citizenId then
                removedFromPatrol = patrol.name
                removedFromId     = pid
                break
            end
        end
        if removedFromPatrol then break end
    end

    -- Remove from patrol
    for _, patrol in pairs(patrols) do
        for i = #patrol.memberIds, 1, -1 do
            if patrol.memberIds[i] == citizenId then
                table.remove(patrol.memberIds, i)
                savePatrol(patrol) -- frequent mutation → debounced
            end
        end
    end

    broadcastPatrols()

    -- Audit log only if they were actually in a patrol
    if removedFromPatrol and ps.auditLog then
        dbg(('%s disconnected from patrol "%s"'):format(officerName, removedFromPatrol))
        ps.auditLog(src, 'patrol_officer_removed', removedFromId or citizenId, {
            officer_name = officerName,
            officer_id   = citizenId,
            removed_from = removedFromPatrol,
            action_label = ('%s left patrol "%s" (disconnected)'):format(officerName, removedFromPatrol),
        })
    end
end)

AddEventHandler("onResourceStart", function(res)
    if res ~= resourceName then return end

    -- Wrapped in pcall so a missing/broken `mdt_patrols` table produces a clear
    -- error for the next dev instead of a hard crash on boot.
    local ok, rows = pcall(function()
        return MySQL.query.await("SELECT * FROM mdt_patrols ORDER BY sort_order ASC")
    end)
    if not ok or type(rows) ~= "table" then
        print(('^1[MDT]^7 Failed to load patrols. Is the `mdt_patrols` table installed? Error: %s')
            :format(tostring(rows)))
        return
    end

    patrolOrder = {}
    for _, row in ipairs(rows) do
        local zonePoints = nil
        if row.zone_points and row.zone_points ~= "" and row.zone_points ~= "null" then
            local okDecode, decoded = pcall(json.decode, row.zone_points)
            if okDecode and type(decoded) == "table" then
                zonePoints = decoded
            else
                print(('^3[MDT]^7 Patrol "%s" has unparseable zone_points; ignoring.'):format(row.id))
            end
        end
        patrols[row.id] = {
            id = row.id,
            name = row.name,
            color = row.color,
            memberIds = {},
            zonePoints = zonePoints,
            sortOrder = row.sort_order or 0,
            domain = (row.job_type == 'ems') and 'ems' or 'police',
        }
        patrolOrder[#patrolOrder + 1] = row.id
    end
    -- Members reset on restart (officers need to be reassigned after a restart)
    MySQL.execute("UPDATE mdt_patrols SET member_ids = '[]'", {})
    ps.debug(('^2[MDT]^7 Loaded %d patrol(s).')
        :format(#rows))
end)

-- Flush any pending debounced saves before the resource stops so nothing queued
-- in the last SAVE_DEBOUNCE_MS window is lost on restart.
AddEventHandler("onResourceStop", function(res)
    if res ~= resourceName then return end
    flushSaves()
end)