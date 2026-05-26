-- server_patrols.lua
local resourceName = tostring(GetCurrentResourceName())
local vehicleCache = {}
local cacheVehicleCooldowns = {}
local patrols = {}       -- { [id] = patrol }
local patrolOrder = {}   -- { id, id, id, ... } – ordered list

-- ─── Validierung ──────────────────────────────────────────────────────────

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

-- ─── DB ───────────────────────────────────────────────────────────────────

local function savePatrol(patrol)
    if not patrol then return end
    MySQL.insert(
        "INSERT INTO mdt_patrols (id, name, color, member_ids, sort_order) VALUES (?, ?, ?, ?, ?) " ..
        "ON DUPLICATE KEY UPDATE name = VALUES(name), color = VALUES(color), member_ids = VALUES(member_ids), sort_order = VALUES(sort_order)",
        { patrol.id, patrol.name, patrol.color, json.encode(patrol.memberIds), patrol.sortOrder or 0 }
    )
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

-- ─── Broadcast ────────────────────────────────────────────────────────────

-- Sends patrols as sorted array instead of map,
-- so all clients see the same order
local function broadcastPatrols(action, citizenid)
    local ordered = {}
    for _, id in ipairs(patrolOrder) do
        if patrols[id] then
            ordered[#ordered + 1] = patrols[id]
        end
    end
    TriggerClientEvent(resourceName .. ":client:syncPatrols", -1, ordered, action, citizenid)
end

-- ─── Tracking ─────────────────────────────────────────────────────────────

local function getAllTrackers()
    local vehicles = {}
    local bodycams = {}
    local seenVehicles = {}

    if exports['qb-core'] then
        local QBCore = exports['qb-core']:GetCoreObject()
        local players = QBCore.Functions.GetQBPlayers() or {}

        for _, player in pairs(players) do
            local data = player.PlayerData
            if not data or not data.job or not data.job.onduty then goto continue end
            if not IsPoliceJob(data.job.name, data.job.type) then goto continue end

            local src = data.source
            local ped = GetPlayerPed(src)
            if not ped or ped == 0 then goto continue end

            local coords = GetEntityCoords(ped)
            bodycams[#bodycams + 1] = {
                citizenid = data.citizenid,
                name = data.charinfo.firstname .. ' ' .. data.charinfo.lastname,
                callsign = data.metadata and data.metadata.callsign or nil,
                rank = data.job.grade and data.job.grade.name or 'Officer',
                coords = { x = coords.x, y = coords.y, z = coords.z },
                heading = GetEntityHeading(ped),
            }

            local veh = GetVehiclePedIsIn(ped, false)
            if veh and veh ~= 0 and not seenVehicles[veh] then
                seenVehicles[veh] = true
                local vCoords = GetEntityCoords(veh)
                local plate = GetVehicleNumberPlateText(veh):gsub('%s+', '')
                local vEntry = {
                    plate = plate,
                    coords = { x = vCoords.x, y = vCoords.y, z = vCoords.z },
                    heading = GetEntityHeading(veh),
                }
                vehicles[#vehicles + 1] = vEntry
                vehicleCache[plate] = vEntry
            end
            ::continue::
        end

    elseif ps and ps.getAllPlayers then
        local playerList = ps.getAllPlayers() or {}
        for _, playerId in pairs(playerList) do
            if not (ps.getJobDuty and ps.getJobDuty(playerId)) then goto continue end
            local jobName = ps.getJobName and ps.getJobName(playerId) or nil
            local jobType = ps.getJobType and ps.getJobType(playerId) or nil
            if not IsPoliceJob(jobName, jobType) then goto continue end

            local ped = GetPlayerPed(playerId)
            if not ped or ped == 0 then goto continue end

            local coords = GetEntityCoords(ped)
            bodycams[#bodycams + 1] = {
                citizenid = ps.getIdentifier and ps.getIdentifier(playerId) or nil,
                name = (ps.getPlayerName and ps.getPlayerName(playerId)) or GetPlayerName(playerId) or 'Unknown',
                callsign = ps.getMetadata and ps.getMetadata(playerId, 'callsign') or nil,
                rank = ps.getJobGradeName and ps.getJobGradeName(playerId) or 'Officer',
                coords = { x = coords.x, y = coords.y, z = coords.z },
                heading = GetEntityHeading(ped),
            }

            local veh = GetVehiclePedIsIn(ped, false)
            if veh and veh ~= 0 and not seenVehicles[veh] then
                seenVehicles[veh] = true
                local vCoords = GetEntityCoords(veh)
                local plate = GetVehicleNumberPlateText(veh):gsub('%s+', '')
                local vEntry = {
                    plate = plate,
                    coords = { x = vCoords.x, y = vCoords.y, z = vCoords.z },
                    heading = GetEntityHeading(veh),
                }
                vehicles[#vehicles + 1] = vEntry
                vehicleCache[plate] = vEntry
            end
            ::continue::
        end
    end

    -- Cached vehicles not currently driven by anyone
    for plate, cacheData in pairs(vehicleCache) do
        if not seenVehicles[cacheData._entity] then
            local alreadyAdded = false
            for _, v in pairs(vehicles) do
                if v.plate == plate then alreadyAdded = true; break end
            end
            if not alreadyAdded then
                vehicles[#vehicles + 1] = cacheData
            end
        end
    end

    return vehicles, bodycams
end

ps.registerCallback(resourceName .. ':server:getTracking', function(source)
    if not CheckAuth(source) then
        return { vehicles = {}, bodycams = {} }
    end
    local vehicles, bodycams = getAllTrackers()
    return { vehicles = vehicles, bodycams = bodycams }
end)

RegisterNetEvent(resourceName .. ':server:cacheVehicle', function(plate, coords, heading)
    local src = source
    if type(plate) ~= 'string' or #plate == 0 or #plate > 8 then return end
    if type(coords) ~= 'table' or type(coords.x) ~= 'number' or type(coords.y) ~= 'number' or type(coords.z) ~= 'number' then return end
    if type(heading) ~= 'number' or heading < 0 or heading > 360 then return end
    if coords.x < -4000 or coords.x > 4000 or coords.y < -4000 or coords.y > 8000 then return end

    local now = os.time()
    if cacheVehicleCooldowns[src] and now - cacheVehicleCooldowns[src] < 5 then return end
    cacheVehicleCooldowns[src] = now

    if exports['qb-core'] then
        local QBCore = exports['qb-core']:GetCoreObject()
        local player = QBCore.Functions.GetPlayer(src)
        if not player then return end
        local job = player.PlayerData.job
        if not job or not job.onduty or not IsPoliceJob(job.name, job.type) then return end
    end

    vehicleCache[plate] = {
        plate = plate,
        coords = { x = coords.x, y = coords.y, z = coords.z },
        heading = heading,
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
    if not CheckAuth(source) then return {} end
    -- Return sorted array
    local ordered = {}
    for _, id in ipairs(patrolOrder) do
        if patrols[id] then
            ordered[#ordered + 1] = patrols[id]
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
    patrols[id] = { id = id, name = name, color = color, memberIds = {}, sortOrder = sortOrder }
    patrolOrder[#patrolOrder + 1] = id
    broadcastPatrols()
    savePatrol(patrols[id])
end)

RegisterNetEvent(resourceName .. ":server:deletePatrol", function(id)
    local src = source
    if not CheckAuth(src) then return end
    if not isValidPatrolId(id) then return end

    patrols[id] = nil
    -- Remove from order list
    for i = #patrolOrder, 1, -1 do
        if patrolOrder[i] == id then
            table.remove(patrolOrder, i)
            break
        end
    end
    deletePatrolFromDB(id)
    saveOrder()
    broadcastPatrols()
end)

RegisterNetEvent(resourceName .. ":server:renamePatrol", function(id, newName)
    local src = source
    if not CheckAuth(src) then return end
    if not isValidPatrolId(id) or not isValidName(newName) then return end
    if not patrols[id] then return end

    patrols[id].name = newName
    broadcastPatrols()
    savePatrol(patrols[id])
end)

-- New order from client – ids is an array of patrol IDs in the desired order
RegisterNetEvent(resourceName .. ":server:reorderPatrols", function(ids)
    local src = source
    if not CheckAuth(src) then return end
    if type(ids) ~= "table" then return end

    -- Validate: only known IDs, no duplicates
    local seen = {}
    local newOrder = {}
    for _, id in ipairs(ids) do
        if isValidPatrolId(id) and patrols[id] and not seen[id] then
            seen[id] = true
            newOrder[#newOrder + 1] = id
        end
    end
    -- Append any missing IDs
    for _, id in ipairs(patrolOrder) do
        if not seen[id] then
            newOrder[#newOrder + 1] = id
        end
    end

    patrolOrder = newOrder
    saveOrder()
    broadcastPatrols()
end)

RegisterNetEvent(resourceName .. ":server:assignOfficer", function(patrolId, citizenId)
    local src = source
    if not CheckAuth(src) then return end
    if not isValidPatrolId(patrolId) or not isValidCitizenId(citizenId) then return end
    if not patrols[patrolId] then return end

    for _, patrol in pairs(patrols) do
        for i = #patrol.memberIds, 1, -1 do
            if patrol.memberIds[i] == citizenId then
                table.remove(patrol.memberIds, i)
            end
        end
    end
    table.insert(patrols[patrolId].memberIds, citizenId)
    broadcastPatrols("assigned", citizenId)
    savePatrol(patrols[patrolId])
end)

RegisterNetEvent(resourceName .. ":server:removeFromPatrol", function(citizenId)
    local src = source
    if not CheckAuth(src) then return end
    if not isValidCitizenId(citizenId) then return end

    for _, patrol in pairs(patrols) do
        for i = #patrol.memberIds, 1, -1 do
            if patrol.memberIds[i] == citizenId then
                table.remove(patrol.memberIds, i)
                savePatrol(patrol)
            end
        end
    end
    broadcastPatrols("removed", citizenId)
end)

AddEventHandler("playerDropped", function()
    cacheVehicleCooldowns[source] = nil

    if exports["qb-core"] then
        local QBCore = exports["qb-core"]:GetCoreObject()
        local player = QBCore.Functions.GetPlayer(source)
        if player then
            local citizenId = player.PlayerData.citizenid
            for _, patrol in pairs(patrols) do
                for i = #patrol.memberIds, 1, -1 do
                    if patrol.memberIds[i] == citizenId then
                        table.remove(patrol.memberIds, i)
                        savePatrol(patrol)
                    end
                end
            end
            broadcastPatrols()
        end
    end
end)

AddEventHandler("onResourceStart", function(res)
    if res ~= resourceName then return end
    local rows = MySQL.query.await("SELECT * FROM mdt_patrols ORDER BY sort_order ASC")
    patrolOrder = {}
    for _, row in ipairs(rows) do
        patrols[row.id] = {
            id = row.id,
            name = row.name,
            color = row.color,
            memberIds = {},
            sortOrder = row.sort_order or 0,
        }
        patrolOrder[#patrolOrder + 1] = row.id
    end
    -- Clear members in DB as well
    MySQL.execute("UPDATE mdt_patrols SET member_ids = '[]'", {})
    print("[MDT] " .. #rows .. " patrols loaded.")
end)