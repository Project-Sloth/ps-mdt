local resourceName = tostring(GetCurrentResourceName())
local vehicleCache = {}
local cacheVehicleCooldowns = {}

local function getAllTrackers()
    local vehicles = {}
    local bodycams = {}
    local seenVehicles = {}

    local players = {}

    if exports['qb-core'] then
        local QBCore = exports['qb-core']:GetCoreObject()
        players = QBCore.Functions.GetQBPlayers() or {}

        for _, player in pairs(players) do
            local data = player.PlayerData
            if not data or not data.job or not data.job.onduty then goto continue end
            if not IsPoliceJob(data.job.name, data.job.type) then goto continue end

            local src = data.source
            local ped = GetPlayerPed(src)
            if not ped or ped == 0 then goto continue end

            local coords = GetEntityCoords(ped)
            local heading = GetEntityHeading(ped)
            local coordsTable = { x = coords.x, y = coords.y, z = coords.z }

            local name = data.charinfo.firstname .. ' ' .. data.charinfo.lastname
            local callsign = data.metadata and data.metadata.callsign or nil
            local rank = data.job.grade and data.job.grade.name or 'Officer'

            local entry = {
                citizenid = data.citizenid,
                name = name,
                callsign = callsign,
                rank = rank,
                coords = coordsTable,
                heading = heading,
            }
            bodycams[#bodycams + 1] = entry

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
            local heading = GetEntityHeading(ped)
            local coordsTable = { x = coords.x, y = coords.y, z = coords.z }
            local name = (ps.getPlayerName and ps.getPlayerName(playerId)) or GetPlayerName(playerId) or 'Unknown'
            local callsign = ps.getMetadata and ps.getMetadata(playerId, 'callsign') or nil

            local entry = {
                citizenid = ps.getIdentifier and ps.getIdentifier(playerId) or nil,
                name = name,
                callsign = callsign,
                rank = ps.getJobGradeName and ps.getJobGradeName(playerId) or 'Officer',
                coords = coordsTable,
                heading = heading,
            }
            bodycams[#bodycams + 1] = entry

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
    if type(coords) ~= 'table' or type(coords.x) ~= 'number'
       or type(coords.y) ~= 'number' or type(coords.z) ~= 'number' then return end
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

AddEventHandler('playerDropped', function()
    cacheVehicleCooldowns[source] = nil
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