local resourceName = tostring(GetCurrentResourceName())

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
                        local coordsTable = { x = coords.x, y = coords.y, z = coords.z }
                        local heading = GetEntityHeading(veh)
                        local plate = GetVehicleNumberPlateText(veh)
                        vehicles[#vehicles + 1] = {
                            plate = plate,
                            coords = coordsTable,
                            heading = heading,
                        }
                    end
                end
            end
        end
    end

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
