-- client_patrols.lua
local resourceName = tostring(GetCurrentResourceName())

-- UI state held in Lua client (survives MDT open/close)
local mapUiState = {
    sidebarOpen  = true,
    officersOpen = true,
    patrolsOpen  = true,
}

-- ─── Server → NUI ─────────────────────────────────────────────────────────

RegisterNetEvent(resourceName .. ":client:syncPatrols", function(patrols, action, citizenid)
    SendNUIMessage({ type = "syncPatrols", data = patrols, action = action, citizenid = citizenid })
end)

RegisterNetEvent(resourceName .. ':client:checkVehicleClass', function(netId, plate, coords, heading)
    local veh = NetworkGetEntityFromNetworkId(netId)
    if not veh or veh == 0 then return end
    if GetVehicleClass(veh) ~= 18 then return end
    TriggerServerEvent(resourceName .. ':server:cacheVehicle', plate, coords, heading)
end)

-- ─── UI State ─────────────────────────────────────────────────────────────

-- Call this in client.lua after SendNUI('setVisible', { visible = true })
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

-- Register only once – always call cb() to prevent timeout
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
    cb({ success = true, data = result or {} })
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