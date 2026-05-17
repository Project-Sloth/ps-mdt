local resourceName = tostring(GetCurrentResourceName())
local vehicleCache = {}

local function getOfficerTrackers()
    local officers = {}

    if exports['qb-core'] then
        local QBCore = exports['qb-core']:GetCoreObject()
        local players = QBCore.Functions.GetQBPlayers() or {}
        for _, player in pairs(players) do
            local data = player.PlayerData
            if data and data.job and data.job.onduty then
                if IsPoliceJob(data.job.name, data.job.type) then
                    local src = data.source
                    local ped = GetPlayerPed(src)
                    if ped and ped ~= 0 then
                        local coords = GetEntityCoords(ped)
                        local coordsTable = { x = coords.x, y = coords.y, z = coords.z }
                        local heading = GetEntityHeading(ped)
                        officers[#officers + 1] = {
                            citizenid = data.citizenid,
                            name = (data.charinfo.firstname .. ' ' .. data.charinfo.lastname),
                            callsign = data.metadata and data.metadata.callsign or nil,
                            rank = data.job.grade and data.job.grade.name or 'Officer',
                            coords = coordsTable,
                            heading = heading,
                        }
                    end
                end
            end
        end
        return officers
    end

    if ps and ps.getAllPlayers then
        local players = ps.getAllPlayers() or {}
        for _, playerId in pairs(players) do
            if ps.getJobDuty and ps.getJobDuty(playerId) then
                local jobName = ps.getJobName and ps.getJobName(playerId) or nil
                local jobType = ps.getJobType and ps.getJobType(playerId) or nil
                if IsPoliceJob(jobName, jobType) then
                    local ped = GetPlayerPed(playerId)
                    if ped and ped ~= 0 then
                        local coords = GetEntityCoords(ped)
                        local coordsTable = { x = coords.x, y = coords.y, z = coords.z }
                        local heading = GetEntityHeading(ped)
                        officers[#officers + 1] = {
                            citizenid = ps.getIdentifier and ps.getIdentifier(playerId) or nil,
                            name = ps.getPlayerName and ps.getPlayerName(playerId) or GetPlayerName(playerId) or 'Unknown',
                            callsign = ps.getMetadata and ps.getMetadata(playerId, 'callsign') or nil,
                            rank = ps.getJobGradeName and ps.getJobGradeName(playerId) or 'Officer',
                            coords = coordsTable,
                            heading = heading,
                        }
                    end
                end
            end
        end
    end
    return officers
end

local function getVehicleTrackers()
    local vehicles = {}
    local seen = {}

    if exports['qb-core'] then
        local QBCore = exports['qb-core']:GetCoreObject()
        local players = QBCore.Functions.GetQBPlayers() or {}
        for _, player in pairs(players) do
            local data = player.PlayerData
            if data and data.job and data.job.onduty and IsPoliceJob(data.job.name, data.job.type) then
                local ped = GetPlayerPed(data.source)
                if ped and ped ~= 0 then
                    local veh = GetVehiclePedIsIn(ped, false)
                    if veh and veh ~= 0 and not seen[veh] then
                        seen[veh] = true
                        local coords = GetEntityCoords(veh)
                        local plate = GetVehicleNumberPlateText(veh):gsub('%s+', '')
                        local entry = {
                            plate = plate,
                            coords = { x = coords.x, y = coords.y, z = coords.z },
                            heading = GetEntityHeading(veh),
                        }
                        vehicles[#vehicles + 1] = entry
                        vehicleCache[plate] = entry
                    end
                end
            end
        end
    end

    if ps and ps.getAllPlayers then
        local players = ps.getAllPlayers() or {}
        for playerId, _ in pairs(players) do
            if ps.getJobDuty(playerId) then
                local jobName = ps.getJobName and ps.getJobName(playerId) or nil
                local jobType = ps.getJobType and ps.getJobType(playerId) or nil
                if IsPoliceJob(jobName, jobType) then
                    local ped = GetPlayerPed(playerId)
                    if ped and ped ~= 0 then
                        local veh = GetVehiclePedIsIn(ped, false)
                        if veh and veh ~= 0 and not seen[veh] then
                            seen[veh] = true
                            local coords = GetEntityCoords(veh)
                            local plate = GetVehicleNumberPlateText(veh):gsub('%s+', '')
                            local entry = {
                                plate = plate,
                                coords = { x = coords.x, y = coords.y, z = coords.z },
                                heading = GetEntityHeading(veh),
                            }
                            vehicles[#vehicles + 1] = entry
                            vehicleCache[plate] = {
                                plate = plate,
                                coords = { x = coords.x, y = coords.y, z = coords.z },
                                heading = GetEntityHeading(veh),
                            }
                        end
                    end
                end
            end
        end
    end

    for plate, cacheData in pairs(vehicleCache) do
        local alreadyLive = false
        for _, v in pairs(vehicles) do
            if v.plate == plate then
                alreadyLive = true
                break
            end
        end
        if not alreadyLive then
            vehicles[#vehicles + 1] = cacheData
        end
    end

    print(json.encode(vehicles, {indent = true}))
    return vehicles
end

local function getBodycamTrackers()
    local bodycams = {}

    if exports['qb-core'] then
        local QBCore = exports['qb-core']:GetCoreObject()
        local players = QBCore.Functions.GetQBPlayers() or {}
        for _, player in pairs(players) do
            local data = player.PlayerData
            if data and data.job and data.job.onduty then
                if IsPoliceJob(data.job.name, data.job.type) then
                    local ped = GetPlayerPed(data.source)
                    if ped and ped ~= 0 then
                        local coords = GetEntityCoords(ped)
                        local coordsTable = { x = coords.x, y = coords.y, z = coords.z }
                        local heading = GetEntityHeading(ped)
                        bodycams[#bodycams + 1] = {
                            citizenid = data.citizenid,
                            name = (data.charinfo.firstname .. ' ' .. data.charinfo.lastname),
                            callsign = data.metadata and data.metadata.callsign or nil,
                            coords = coordsTable,
                            heading = heading,
                        }
                    end
                end
            end
        end
        return bodycams
    end

    if ps and ps.getAllPlayers then
        local players = ps.getAllPlayers() or {}
        for _, playerId in pairs(players) do
            if ps.getJobDuty and ps.getJobDuty(playerId) then
                local jobName = ps.getJobName and ps.getJobName(playerId) or nil
                local jobType = ps.getJobType and ps.getJobType(playerId) or nil
                if IsPoliceJob(jobName, jobType) then
                    local ped = GetPlayerPed(playerId)
                    if ped and ped ~= 0 then
                        local coords = GetEntityCoords(ped)
                        local coordsTable = { x = coords.x, y = coords.y, z = coords.z }
                        local heading = GetEntityHeading(ped)
                        bodycams[#bodycams + 1] = {
                            citizenid = ps.getIdentifier and ps.getIdentifier(playerId) or nil,
                            name = ps.getPlayerName and ps.getPlayerName(playerId) or GetPlayerName(playerId) or 'Unknown',
                            callsign = ps.getMetadata and ps.getMetadata(playerId, 'callsign') or nil,
                            coords = coordsTable,
                            heading = heading,
                        }
                    end
                end
            end
        end
    end
    return bodycams
end

ps.registerCallback(resourceName .. ':server:getTracking', function(source)
    local src = source
    if not CheckAuth(src) then return { officers = {}, vehicles = {}, bodycams = {} } end

    return {
        officers = getOfficerTrackers(),
        vehicles = getVehicleTrackers(),
        bodycams = getBodycamTrackers(),
    }
end)

RegisterNetEvent('baseevents:leftVehicle', function(vehicle, seat, model, netId)
    local src = source
    if not CheckAuth(src) then return end

    if exports['qb-core'] then
        local QBCore = exports['qb-core']:GetCoreObject()
        local player = QBCore.Functions.GetPlayer(src)
        if not player then return end
        local job = player.PlayerData.job
        if not job or not job.onduty or not IsPoliceJob(job.name, job.type) then return end
    end

    local veh = NetworkGetEntityFromNetworkId(netId)
    if not veh or veh == 0 then return end

    local coords = GetEntityCoords(veh)
    local heading = GetEntityHeading(veh)
    local plate = GetVehicleNumberPlateText(veh):gsub('%s+', '')
    if not plate or #plate == 0 then return end

    TriggerClientEvent(resourceName .. ':client:checkVehicleClass', src, netId, plate, { x = coords.x, y = coords.y, z = coords.z }, heading)
end)

RegisterNetEvent(resourceName .. ':server:cacheVehicle', function(plate, coords, heading)
    local src = source
    if not CheckAuth(src) then return end

    if exports['qb-core'] then
        local QBCore = exports['qb-core']:GetCoreObject()
        local player = QBCore.Functions.GetPlayer(src)
        if not player then return end
        local job = player.PlayerData.job
        if not job or not job.onduty or not IsPoliceJob(job.name, job.type) then return end
    end

    if not plate or type(plate) ~= 'string' or #plate == 0 or #plate > 8 then return end

    if type(coords) ~= 'table' or not coords.x or not coords.y or not coords.z then return end
    if type(coords.x) ~= 'number' or type(coords.y) ~= 'number' or type(coords.z) ~= 'number' then return end

    if not heading or type(heading) ~= 'number' then return end
    if heading < 0 or heading > 360 then return end

    if coords.x < -4000 or coords.x > 4000 or coords.y < -4000 or coords.y > 8000 then return end

    -- rate limit pro spieler
    local cooldowns = {}
    if cooldowns[src] and os.time() - cooldowns[src] < 5 then
        ps.warn('Rate limit hit for ' .. src)
        return
    end
    cooldowns[src] = os.time()

    if not vehicleCache[plate] then
        ps.info(plate .. ' was added into vehicleCache for Maps')
    end

    vehicleCache[plate] = {
        plate = plate,
        coords = { x = coords.x, y = coords.y, z = coords.z },
        heading = heading,
    }
end)

AddEventHandler('entityRemoved', function(entity)
    if GetEntityType(entity) ~= 2 then return end -- 2 = vehicle

    local plate = GetVehicleNumberPlateText(entity)
    if not plate or plate == '' then return end
    plate = plate:gsub('%s+', '')

    if vehicleCache[plate] then
        ps.success(plate .. ' despawned, removing from vehicleCache')
        vehicleCache[plate] = nil
    end
end)