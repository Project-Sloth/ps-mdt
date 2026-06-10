-- ----------------------------------------------------------------------------
--  Responsibilities:
--    * Forwards patrol/tracking data between server and the map NUI.
--    * Maintains one ox_lib PolyZone per patrol and fires enter/exit
--      notifications, but ONLY for the patrol the local player belongs to.
--    * Zones live independently of the MDT: they are built on spawn and on
--      resource start, so notifications work without ever opening the MDT.
--
--  Performance notes for future devs:
--    * syncPatrols is broadcast to ALL clients on EVERY patrol mutation
--      (create/delete/assign/remove/rename/reorder/zone). syncZones() therefore
--      diffs each zone's geometry signature and only rebuilds zones whose points
--      actually changed — a rename/reorder/assign no longer tears down and
--      recreates every PolyZone on every client.
--    * Patrol names shown in zone notifications are read live from
--      zonePatrolNames, so a rename never forces a zone rebuild.
--
--  Set MDT_DEBUG = true for verbose console logging while developing.
-- ============================================================================

local resourceName = tostring(GetCurrentResourceName())

-- ─── Tunables ───────────────────────────────────────────────────────────────
local MDT_DEBUG = false -- verbose dev logging; KEEP FALSE on production

local function dbg(...)
    if MDT_DEBUG then print('[MDT]', ...) end
end

-- UI state held in Lua client (survives MDT open/close)
local mapUiState = {
    sidebarOpen  = true,
    officersOpen = true,
    patrolsOpen  = true,
}

-- ─── Patrol zone notification preference ─────────────────────────────────────
-- Read from localStorage via a NUI message on resource start.
-- Defaults to true (enabled) until the NUI reports otherwise.
local patrolZoneNotificationsEnabled = true

AddEventHandler('onClientResourceStart', function(res)
    if res ~= resourceName then return end
    -- Ask the NUI to send us the stored preference
    SendNUIMessage({ type = 'requestPatrolZonePref' })
end)

-- The NUI page reads localStorage and sends this back
RegisterNUICallback('patrolZonePref', function(data, cb)
    if type(data.enabled) == 'boolean' then
        patrolZoneNotificationsEnabled = data.enabled
    end
    cb({})
end)

-- ─── Notification helper (works with QBCore, ox_lib, ps-ui) ─────────────────

local function mdtNotify(title, description, notifyType, duration)
    -- Respect the player's preference stored in localStorage via NUI
    if not patrolZoneNotificationsEnabled then return end
    duration = duration or 4000
    if exports['ox_lib'] then
        lib.notify({ title = title, description = description, type = notifyType, duration = duration })
    elseif exports['qb-core'] then
        exports['qb-core']:GetCoreObject().Functions.Notify(('[%s] %s'):format(title, description), notifyType, duration)
    elseif exports['ps-ui'] then
        exports['ps-ui']:Notify({ text = ('[%s] %s'):format(title, description), type = notifyType, length = duration })
    else
        BeginTextCommandThefeedPost('STRING')
        AddTextComponentSubstringPlayerName(('[%s] %s'):format(title, description))
        EndTextCommandThefeedPostTick()
    end
end

-- ─── Patrol Zone tracking ──────────────────────────────────────────────────
-- Keeps one PolyZone per patrol id. Zones are (re)built only when their
-- geometry changes (see syncZones).

local activeZones     = {}  -- [patrolId] = ox_lib PolyZone object
local zoneSignatures  = {}  -- [patrolId] = geometry signature (string)
local zonePatrolNames = {}  -- [patrolId] = latest patrol name (read live by callbacks)
local myPatrolId      = nil -- patrol the local player currently belongs to

local function getCitizenId()
    if exports['qb-core'] then
        return exports['qb-core']:GetCoreObject().Functions.GetPlayerData().citizenid
    elseif ps and ps.getIdentifier then
        return ps.getIdentifier()
    end
    return nil
end

local function destroyZone(patrolId)
    if activeZones[patrolId] then
        activeZones[patrolId]:remove()
        activeZones[patrolId] = nil
    end
end

local function destroyAllZones()
    for id in pairs(activeZones) do
        destroyZone(id)
    end
    zoneSignatures  = {}
    zonePatrolNames = {}
end

-- A cheap, stable string fingerprint of a zone's points. Identical geometry =>
-- identical signature => no rebuild needed.
local function pointsSignature(points)
    if not points then return "" end
    local parts = {}
    for i = 1, #points do
        parts[i] = string.format("%.1f,%.1f", points[i].x or 0.0, points[i].y or 0.0)
    end
    return table.concat(parts, ";")
end

-- Convert GTA world {x,y} array → ox_lib poly-zone points (vector3; z required,
-- but ignored by lib.zones.poly).
local function toVector3List(points)
    local vecs = {}
    for i = 1, #points do
        vecs[i] = vector3(points[i].x, points[i].y, 0.0)
    end
    return vecs
end

local function createZoneForPatrol(patrol)
    destroyZone(patrol.id)

    local points = patrol.zonePoints
    if not points or #points < 3 then return end

    local vecs = toVector3List(points)
    local pid  = patrol.id

    -- Suppress the initial onEnter that fires when the zone is first created
    -- (happens on spawn, MDT open, resource restart)
    local suppressInitial = true
    SetTimeout(2500, function() suppressInitial = false end)

    local zone = lib.zones.poly({
        points    = vecs,
        thickness = 1600,
        debug     = false,
        onEnter   = function()
            if pid ~= myPatrolId then return end
            if suppressInitial then return end
            mdtNotify(zonePatrolNames[pid] or 'Patrol', 'entered Zone', 'success', 3000)
        end,
        onExit    = function()
            if pid ~= myPatrolId then return end
            mdtNotify(zonePatrolNames[pid] or 'Patrol', 'left Zone', 'error', 5000)
        end,
    })

    activeZones[pid] = zone
end

-- Rebuild only the zones whose geometry changed, and figure out which patrol the
-- local player is in. Cheap to call on every syncPatrols broadcast.
local function syncZones(patrols)
    local citizenId = getCitizenId()
    myPatrolId = nil

    -- Destroy zones for patrols that no longer exist
    local incoming = {}
    for _, p in ipairs(patrols) do incoming[p.id] = true end
    for id in pairs(activeZones) do
        if not incoming[id] then
            destroyZone(id)
            zoneSignatures[id]  = nil
            zonePatrolNames[id] = nil
        end
    end

    for _, patrol in ipairs(patrols) do
        -- Keep the name fresh so renames update notifications without a rebuild
        zonePatrolNames[patrol.id] = patrol.name

        -- Resolve local membership
        if citizenId then
            for _, mid in ipairs(patrol.memberIds) do
                if mid == citizenId then
                    myPatrolId = patrol.id
                    break
                end
            end
        end

        local hasZone = patrol.zonePoints and #patrol.zonePoints >= 3
        if hasZone then
            local sig = pointsSignature(patrol.zonePoints)
            if zoneSignatures[patrol.id] ~= sig then
                createZoneForPatrol(patrol)
                zoneSignatures[patrol.id] = sig
                dbg(('rebuilt zone for "%s" (%d pts)'):format(patrol.name, #patrol.zonePoints))
            end
        else
            if activeZones[patrol.id] then destroyZone(patrol.id) end
            zoneSignatures[patrol.id] = nil
        end
    end
end

-- ─── Server → NUI ─────────────────────────────────────────────────────────

RegisterNetEvent(resourceName .. ":client:syncPatrols", function(patrols, action, citizenid)
    SendNUIMessage({ type = "syncPatrols", data = patrols, action = action, citizenid = citizenid })

    -- Rebuild PolyZones whenever patrol data changes (diffed inside syncZones)
    if type(patrols) == "table" then
        syncZones(patrols)
    end
end)

-- Called from client.lua after setVisible(true) — send citizenId so map centers on self
function SendMapCitizenId()
    local cid = getCitizenId()
    if cid then
        SendNUIMessage({ type = 'setLocalCitizenId', data = { citizenid = cid } })
    end
end

RegisterNetEvent(resourceName .. ':client:checkVehicleClass', function(netId, plate, coords, heading)
    local veh = NetworkGetEntityFromNetworkId(netId)
    if not veh or veh == 0 then return end
    if GetVehicleClass(veh) ~= 18 then return end -- 18 = Emergency
    TriggerServerEvent(resourceName .. ':server:cacheVehicle', plate, coords, heading)
end)

-- ─── UI State ─────────────────────────────────────────────────────────────

function SendMapUiState()
    SendNUIMessage({ type = "mapUiState", data = mapUiState })
end

RegisterNUICallback("saveMapUiState", function(data, cb)
    if type(data.key) == "string" and type(data.value) == "boolean" then
        mapUiState[data.key] = data.value
    end
    cb({})
end)

-- ─── Tracking ─────────────────────────────────────────────────────────────

RegisterNUICallback("getTracking", function(_, cb)
    if not MDTOpen then
        cb({ success = false, data = { vehicles = {}, bodycams = {} } })
        return
    end

    local tracking = ps.callback(resourceName .. ":server:getTracking")
    if tracking then
        cb({ success = true, data = tracking })
    else
        cb({ success = false, data = { vehicles = {}, bodycams = {} } })
    end
end)

-- ─── Patrols ──────────────────────────────────────────────────────────────

RegisterNUICallback("getPatrols", function(_, cb)
    local result = ps.callback(resourceName .. ":server:getPatrols")
    local patrols = result or {}
    cb({ success = true, data = patrols })
    -- Also sync zones immediately on load
    if type(patrols) == "table" then
        syncZones(patrols)
    end
end)

RegisterNUICallback("createPatrol", function(data, cb)
    if not MDTOpen then cb({ success = false }) return end
    local id, name, color = data.id, data.name, data.color
    if type(id) ~= "string" or type(name) ~= "string" or type(color) ~= "string" then
        cb({ success = false }) return
    end
    TriggerServerEvent(resourceName .. ":server:createPatrol", id, name, color)
    cb({ success = true })
end)

RegisterNUICallback("deletePatrol", function(data, cb)
    if not MDTOpen then cb({ success = false }) return end
    if type(data.id) ~= "string" then cb({ success = false }) return end
    TriggerServerEvent(resourceName .. ":server:deletePatrol", data.id)
    cb({ success = true })
end)

RegisterNUICallback("renamePatrol", function(data, cb)
    if not MDTOpen then cb({ success = false }) return end
    if type(data.id) ~= "string" or type(data.name) ~= "string" then
        cb({ success = false }) return
    end
    TriggerServerEvent(resourceName .. ":server:renamePatrol", data.id, data.name)
    cb({ success = true })
end)

RegisterNUICallback("assignOfficer", function(data, cb)
    if not MDTOpen then cb({ success = false }) return end
    if type(data.patrolId) ~= "string" or type(data.citizenId) ~= "string" then
        cb({ success = false }) return
    end
    TriggerServerEvent(resourceName .. ":server:assignOfficer", data.patrolId, data.citizenId)
    cb({ success = true })
end)

RegisterNUICallback("reorderPatrols", function(data, cb)
    if not MDTOpen then cb({ success = false }) return end
    if type(data.ids) ~= "table" then cb({ success = false }) return end
    TriggerServerEvent(resourceName .. ":server:reorderPatrols", data.ids)
    cb({ success = true })
end)

RegisterNUICallback("removeFromPatrol", function(data, cb)
    if not MDTOpen then cb({ success = false }) return end
    if type(data.citizenId) ~= "string" then cb({ success = false }) return end
    TriggerServerEvent(resourceName .. ":server:removeFromPatrol", data.citizenId)
    cb({ success = true })
end)

-- ─── Cleanup ──────────────────────────────────────────────────────────────

AddEventHandler("onResourceStop", function(res)
    if res ~= resourceName then return end
    destroyAllZones()
end)

-- ─── Auto-init zones on spawn (independent of MDT) ────────────────────────
-- Loads patrol zone data from the server as soon as the player spawns, so zone
-- entry/exit notifications work without ever opening the MDT.

local function initZonesFromServer()
    -- Send citizenId so the map can center on the officer's own position
    local cid = getCitizenId()
    if cid then
        SendNUIMessage({ type = 'setLocalCitizenId', data = { citizenid = cid } })
    end

    local result = ps.callback(resourceName .. ":server:getPatrols")
    if type(result) == "table" then
        syncZones(result)
    end
end

-- Fires when the player first spawns
RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    -- Small delay so the framework has finished setting up the player
    SetTimeout(2000, initZonesFromServer)
end)

-- ─── Zone Drawing ─────────────────────────────────────────────────────────
-- Called by the Svelte map after the user finishes drawing a zone polygon.
-- data.id     = patrol id (string)
-- data.points = array of { x, y } in GTA world coordinates, or nil to clear
RegisterNUICallback("setPatrolZone", function(data, cb)
    if not MDTOpen then cb({ success = false }) return end
    if type(data.id) ~= "string" then cb({ success = false }) return end

    -- Validate points on client before sending to server
    local points = data.points
    if points ~= nil then
        if type(points) ~= "table" or #points < 3 then
            cb({ success = false, error = "need_3_points" }) return
        end
        for _, pt in ipairs(points) do
            if type(pt) ~= "table" or type(pt.x) ~= "number" or type(pt.y) ~= "number" then
                cb({ success = false, error = "invalid_point" }) return
            end
        end
    end

    TriggerServerEvent(resourceName .. ":server:setPatrolZone", data.id, points)
    cb({ success = true })
end)