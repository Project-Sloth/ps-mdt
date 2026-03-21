local resourceName = tostring(GetCurrentResourceName())
local bodycamInstances = {}
local bodycamViewers = {}

local function shouldUseQbCore()
    local cfg = Config and Config.Bodycam or {}
    local resourceName = cfg.DutyResource or 'qb-core'
    if cfg.DutyEventMode == 'pslib' then
        return false
    end
    return exports[resourceName] ~= nil
end

local function getQbCoreObject()
    local cfg = Config and Config.Bodycam or {}
    local resourceName = cfg.DutyResource or 'qb-core'
    local resource = exports[resourceName]
    if not resource then
        return nil
    end
    return resource:GetCoreObject()
end

local function getOnDutyOfficers()
    local officers = {}

    if shouldUseQbCore() then
        local QBCore = getQbCoreObject()
        if QBCore and QBCore.Functions and QBCore.Functions.GetQBPlayers then
            local players = QBCore.Functions.GetQBPlayers() or {}
            for _, player in pairs(players) do
                local data = player.PlayerData
                if data and data.job and data.job.onduty and IsPoliceJob(data.job.name, data.job.type) then
                    officers[#officers + 1] = player
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
                    local player = ps.getPlayer and ps.getPlayer(playerId) or nil
                    if player then
                        officers[#officers + 1] = player
                    end
                end
            end
        end
    end

    return officers
end

-- Get all bodycams for on-duty officers
ps.registerCallback(resourceName .. ':server:getBodycams', function(source)
    local src = source
    ps.debug('getBodycams called by source:', src)

    if not CheckAuth(src) then
        ps.debug('getBodycams: CheckAuth failed for source:', src)
        return {}
    end

    ps.debug('getBodycams: CheckAuth passed for source:', src)
    local bodycams = {}

    local officers = getOnDutyOfficers()
    ps.debug('getBodycams: Found on-duty officers:', officers and #officers or 0)

    for _, player in pairs(officers or {}) do
        local playerData = player.PlayerData
        if playerData then
            local bodycamId = tostring(playerData.source)
            local officerName = playerData.charinfo.firstname .. ' ' .. playerData.charinfo.lastname

            if not bodycamInstances[bodycamId] then
                bodycamInstances[bodycamId] = {
                    id = bodycamId,
                    officerName = officerName,
                    callsign = playerData.metadata and playerData.metadata.callsign or 'Unknown',
                    rank = playerData.job.grade and playerData.job.grade.name or 'Officer',
                    playerId = playerData.source,
                    isOnline = true,
                    createdAt = os.time()
                }
                ps.debug('Created bodycam on-demand for officer:', officerName, 'ID:', bodycamId)
            else
                local data = bodycamInstances[bodycamId]
                data.officerName = officerName
                data.callsign = playerData.metadata and playerData.metadata.callsign or 'Unknown'
                data.rank = playerData.job.grade and playerData.job.grade.name or 'Officer'
            end
        end
    end

    local instanceCount = 0
    for _ in pairs(bodycamInstances) do
        instanceCount = instanceCount + 1
    end
    ps.debug('getBodycams: Total bodycam instances before verification:', instanceCount)
    for bodycamId, _ in pairs(bodycamInstances) do
        ps.debug('getBodycams: Bodycam instance found:', bodycamId)
    end

    for bodycamId, data in pairs(bodycamInstances) do
        ps.debug('getBodycams: Verifying bodycam:', bodycamId, 'for player:', data.playerId)
        local isStillOnline = false

        local player = nil
        if shouldUseQbCore() then
            local QBCore = getQbCoreObject()
            if QBCore and QBCore.Functions and QBCore.Functions.GetPlayer then
                player = QBCore.Functions.GetPlayer(data.playerId)
            end
        elseif ps and ps.getPlayer then
            player = ps.getPlayer(data.playerId)
        end

        if player and player.PlayerData and player.PlayerData.job and player.PlayerData.job.onduty then
            isStillOnline = true
            ps.debug('getBodycams: Officer verified as online:', data.officerName)
        end

        ps.debug('getBodycams: Officer', data.officerName, 'isStillOnline:', isStillOnline)

        if isStillOnline then
            local viewerCount = 0
            if bodycamViewers[bodycamId] then
                for _ in pairs(bodycamViewers[bodycamId]) do
                    viewerCount = viewerCount + 1
                end
            end

            table.insert(bodycams, {
                id = bodycamId,
                officerName = data.officerName,
                callsign = data.callsign,
                rank = data.rank,
                isOnline = true,
                viewerCount = viewerCount,
            })
            ps.debug('getBodycams: Added bodycam to return list:', bodycamId, 'with', viewerCount, 'viewers')
        else
            -- Remove offline bodycam
            bodycamInstances[bodycamId] = nil
            ps.debug('getBodycams: Removed offline bodycam:', bodycamId)
        end
    end

    ps.debug('getBodycams: Returning', #bodycams, 'bodycams')
    return bodycams
end)

-- View a specific bodycam
ps.registerCallback(resourceName .. ':server:viewBodycam', function(source, bodycamId)
    local src = source
    if not CheckAuth(src) then
        return { success = false, error = "Unauthorized" }
    end

    local bodycamData = bodycamInstances[bodycamId]
    if not bodycamData then
        return { success = false, error = "Bodycam not found" }
    end

    local targetSource = bodycamData.playerId
    if not targetSource then
        return { success = false, error = "Invalid target source" }
    end

    local targetPlayer = GetPlayerName(targetSource)
    if not targetPlayer then
        return { success = false, error = "Officer is no longer online" }
    end

    local targetPed = GetPlayerPed(targetSource)
    if not targetPed or targetPed == 0 then
        return { success = false, error = "Unable to access officer's bodycam" }
    end

    local coords = GetEntityCoords(targetPed)
    local heading = GetEntityHeading(targetPed)

    -- Start bodycam view for the requesting player
    TriggerClientEvent(resourceName .. ':client:startCameraView', src, {
        coords = coords,
        rotation = vector3(0.0, 0.0, heading),
        networkId = nil, -- No entity to hide for bodycams
        isBodycam = true,
        targetSource = targetSource
    })

    -- Track this viewer
    if not bodycamViewers[bodycamId] then
        bodycamViewers[bodycamId] = {}
    end
    bodycamViewers[bodycamId][src] = {
        startTime = os.time()
    }
    ps.debug('Added viewer', src, 'to bodycam', bodycamId)

    return {
        success = true,
        camera = {
            id = bodycamId,
            label = bodycamData.officerName .. " Bodycam",
            coords = coords,
            rotation = vector3(0.0, 0.0, heading)
        }
    }
end)

-- Clean up bodycam when player disconnects
AddEventHandler('playerDropped', function(reason)
    local playerId = source
    local bodycamId = tostring(playerId)

    if bodycamInstances[bodycamId] then
        bodycamInstances[bodycamId] = nil
        ps.debug('Cleaned up bodycam instance for disconnected player:', playerId)
    end

    -- Clean up any viewer entries for this player
    for bcId, viewers in pairs(bodycamViewers) do
        if viewers and viewers[playerId] then
            viewers[playerId] = nil
            ps.debug('Removed viewer', playerId, 'from bodycam', bcId, 'due to disconnect')
        end
    end
end)

-- Handle bodycam view deactivation
RegisterNetEvent(resourceName .. ':server:deactivateBodycam', function(bodycamId)
    local playerId = source
    if not CheckAuth(playerId) then return end
    ps.debug('Deactivating bodycam for player:', playerId, 'Bodycam ID:', bodycamId)

    if bodycamViewers[bodycamId] then
        ps.debug('Found viewer table for bodycam:', bodycamId)
        if bodycamViewers[bodycamId][playerId] then
            local viewDuration = os.time() - bodycamViewers[bodycamId][playerId].startTime
            bodycamViewers[bodycamId][playerId] = nil
            ps.debug('Player', playerId, 'stopped viewing bodycam', bodycamId, 'after', viewDuration, 'seconds')

            -- Clean up empty viewer table
            if next(bodycamViewers[bodycamId]) == nil then
                bodycamViewers[bodycamId] = nil
                ps.debug('Cleaned up empty viewer table for bodycam:', bodycamId)
            end
        else
            ps.debug('Player', playerId, 'was not found in viewers for bodycam:', bodycamId)
        end
    else
        ps.debug('No viewer table found for bodycam:', bodycamId)
    end
end)

-- Helper function to create bodycam for officer
local function createOfficerBodycam(playerId, playerData)
    local bodycamId = tostring(playerId)
    local officerName = playerData.charinfo.firstname .. ' ' .. playerData.charinfo.lastname

    bodycamInstances[bodycamId] = {
        id = bodycamId,
        officerName = officerName,
        callsign = (playerData.metadata and playerData.metadata.callsign) or 'Unknown',
        rank = (playerData.job and playerData.job.grade and playerData.job.grade.name) or 'Officer',
        playerId = playerId,
        isOnline = true,
        createdAt = os.time()
    }

    ps.debug('Created bodycam for officer:', officerName, 'ID:', bodycamId)
end

-- Helper function to remove bodycam for officer
local function removeOfficerBodycam(playerId)
    local bodycamId = tostring(playerId)

    if bodycamInstances[bodycamId] then
        bodycamInstances[bodycamId] = nil
        ps.debug('Removed bodycam for officer going off duty:', playerId)
    end
end

-- Listen for QBCore duty status changes
local function handleDutyChange(playerId, job, onDuty, employeeData)
    local jobName = job and job.name or employeeData and employeeData.job or nil
    local jobType = job and job.type or employeeData and employeeData.jobType or nil
    if not IsPoliceJob(jobName, jobType) then
        return
    end

    if onDuty then
        local playerData = nil
        if employeeData and employeeData.name then
            playerData = {
                charinfo = {
                    firstname = employeeData.firstname or '',
                    lastname = employeeData.lastname or '',
                },
                metadata = { callsign = employeeData.callsign },
                job = {
                    grade = { name = employeeData.rank or 'Officer' },
                }
            }
            if employeeData.name then
                local nameParts = {}
                for part in tostring(employeeData.name):gmatch('%S+') do
                    nameParts[#nameParts + 1] = part
                end
                playerData.charinfo.firstname = nameParts[1] or employeeData.name
                playerData.charinfo.lastname = nameParts[#nameParts] or ''
            end
            createOfficerBodycam(playerId, playerData)
            ps.debug('Created bodycam via duty event for officer:', employeeData.name, 'ID:', tostring(playerId))
            return
        end

        if shouldUseQbCore() then
            local QBCore = getQbCoreObject()
            local Player = QBCore and QBCore.Functions and QBCore.Functions.GetPlayer and QBCore.Functions.GetPlayer(playerId) or nil
            if Player then
                createOfficerBodycam(playerId, Player.PlayerData)
                return
            end
        elseif ps and ps.getPlayer then
            local player = ps.getPlayer(playerId)
            if player and player.PlayerData then
                createOfficerBodycam(playerId, player.PlayerData)
                return
            end
        end
    else
        removeOfficerBodycam(playerId)
    end
end

local function registerDutyEvents()
    local cfg = Config and Config.Bodycam or {}
    local dutyEvent = cfg.DutyEvent or 'QBCore:Server:OnJobUpdate'
    local dutyMode = cfg.DutyEventMode or 'qbcore'
    local multiJobEvent = cfg.MultiJobDutyEvent or 'ps-multijob:server:dutyChanged'

    if dutyMode == 'qbcore' then
        RegisterNetEvent(dutyEvent, function(source, job)
            local src = source
            if not src or not job then return end
            handleDutyChange(src, job, job.onduty == true, nil)
        end)
    elseif dutyMode == 'pslib' then
        RegisterNetEvent(dutyEvent, function(playerId, jobName, onDuty, employeeData)
            if not playerId then return end
            handleDutyChange(playerId, { name = jobName }, onDuty == true, employeeData)
        end)
    end

    if multiJobEvent then
        RegisterNetEvent(multiJobEvent, function(playerId, jobName, onDuty, employeeData)
            if not playerId then return end
            handleDutyChange(playerId, { name = jobName }, onDuty == true, employeeData)
        end)
    end
end

-- Initialize bodycams for officers already on duty when resource starts
CreateThread(function()
    Wait(5000)

    local cfg = Config and Config.Bodycam or {}
    local multiJobResource = cfg.MultiJobResource or 'ps-multijob'
    if multiJobResource and exports[multiJobResource] then
        local police = exports[multiJobResource]:getEmployees('police')
        if police then
            for _, officer in pairs(police) do
                if officer.citizenid then
                    if shouldUseQbCore() then
                        local QBCore = getQbCoreObject()
                        local Player = QBCore and QBCore.Functions and QBCore.Functions.GetPlayerByCitizenId and QBCore.Functions.GetPlayerByCitizenId(officer.citizenid) or nil
                        if Player and Player.PlayerData.job and Player.PlayerData.job.onduty then
                            createOfficerBodycam(Player.PlayerData.source, Player.PlayerData)
                        end
                    elseif ps and ps.getPlayerByIdentifier then
                        local player = ps.getPlayerByIdentifier(officer.citizenid)
                        if player and player.PlayerData and player.PlayerData.job and player.PlayerData.job.onduty then
                            createOfficerBodycam(player.PlayerData.source, player.PlayerData)
                        end
                    end
                end
            end
        end
    elseif shouldUseQbCore() then
        local QBCore = getQbCoreObject()
        local players = QBCore and QBCore.Functions and QBCore.Functions.GetQBPlayers and QBCore.Functions.GetQBPlayers() or {}

        for _, player in pairs(players or {}) do
            local playerData = player.PlayerData
            if playerData and playerData.job and playerData.job.onduty and IsPoliceJob(playerData.job.name, playerData.job.type) then
                createOfficerBodycam(player.PlayerData.source, playerData)
            end
        end
    else
        local officers = getOnDutyOfficers()
        for _, player in pairs(officers or {}) do
            if player and player.PlayerData then
                createOfficerBodycam(player.PlayerData.source, player.PlayerData)
            end
        end
    end

    local instanceCount = 0
    for _ in pairs(bodycamInstances) do
        instanceCount = instanceCount + 1
    end
    -- do not spell this with a Z
    ps.debug('Initialised ' .. instanceCount .. ' bodycams')
end)

registerDutyEvents()
