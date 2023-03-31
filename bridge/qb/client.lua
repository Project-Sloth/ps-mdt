if Framework.initials ~= "qb" then return end

Framework.TriggerServerCallback = Framework.object.Functions.TriggerCallback --[[@as function]]

Framework.GetPlayerData = Framework.object.Functions.GetPlayerData --[[@as function]]

Framework.AllVehicles = Framework.object.Shared.Vehicles --[[@as table]]

function Framework.IsPlayerLoaded()
    return LocalPlayer.state.isLoggedIn
end

function Framework.GetPlayerCitizenId()
    return Framework.PlayerData?.citizenid
end

function Framework.GetPlayerFirstName()
    return CapitalFirstLetter(Framework.PlayerData?.charinfo?.firstname)
end

function Framework.GetPlayerLastName()
    return CapitalFirstLetter(Framework.PlayerData?.charinfo?.lastname)
end

function Framework.GetPlayerBirthDate()
    return Framework.PlayerData?.charinfo?.birthdate
end

function Framework.GetPlayerJobName()
    return Framework.PlayerData?.job?.name
end

function Framework.GetPlayerJobDuty()
    return Framework.PlayerData?.job?.onduty
end

function Framework.GetPlayerJobGradeName()
    return Framework.PlayerData?.job?.grade?.name
end

function Framework.GetPlayerJobType()
    return Framework.PlayerData?.job?.type
end

function Framework.IsPlayerLEO()
    return Framework.GetPlayerJobType() == "leo"
end

function Framework.GetPlayerCallsign()
    return Framework.PlayerData?.metadata?.callsign
end

function Framework.CanPlayerOpenMDT()
    return not Framework.PlayerData?.metadata?.isdead and not Framework.PlayerData?.metadata?.inlaststand and not Framework.PlayerData?.metadata?.ishandcuffed
end

function Framework.Notification(message, type)
    return Framework.object.Functions.Notify(message, type)
end

-- Uses the QB-Core bill command to send a fine to a player
-- If you use a different fine system, you will need to change this
function Framework.BillPlayer(targetSourceId, fineAmount)
    -- Uses QB-Core /bill command
    ExecuteCommand(('bill %s %s'):format(targetSourceId, fineAmount))
end

-- If you use a different community service system, you will need to change this
function Framework.SendPlayerToCommunityService(targetSourceId, sentence)
    TriggerServerEvent("qb-communityservice:server:StartCommunityService", targetSourceId, sentence)
end

-- Uses qb-policejob JailPlayer event
-- If you use a different jail system, you will need to change this
function Framework.JailPlayer(targetSourceId, sentence)
    TriggerServerEvent("police:server:JailPlayer", targetSourceId, sentence)
end

function Framework.ToggleDuty()
    TriggerServerEvent('QBCore:ToggleDuty')
    TriggerServerEvent("ps-mdt:server:ClockSystem")
end

function Framework.SpawnVehicle(vehicleModel, cb, coords, networked)
    return Framework.object.Functions.SpawnVehicle(vehicleModel, cb, coords, networked, false)
end

function Framework.SetVehicleProperties(vehicle, props)
    return Framework.object.Functions.SetVehicleProperties(vehicle, props)
end

function Framework.GetPlate(vehicle)
    return vehicle ~= 0 and Framework.object.Shared.Trim(GetVehicleNumberPlateText(vehicle))
end

-- Events from qbcore
RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    Framework.PlayerData = Framework.object.Functions.GetPlayerData()
end)

RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    TriggerServerEvent("ps-mdt:server:OnPlayerUnload")
    Framework.PlayerData = {}
end)

RegisterNetEvent('QBCore:Player:SetPlayerData', function(val)
    Framework.PlayerData = val
end)

RegisterNetEvent('QBCore:Client:OnJobUpdate', function(JobInfo)
    Framework.PlayerData.job = JobInfo
end)

RegisterNetEvent('QBCore:Client:OnGangUpdate', function(GangInfo)
    Framework.PlayerData.gang = GangInfo
end)

RegisterNetEvent("QBCore:Client:SetDuty", function(job, state)
    if AllowedJob(job) then
        TriggerServerEvent("ps-mdt:server:ToggleDuty")
        Framework.ToggleDuty() -- I don't get why `TriggerServerEvent('QBCore:ToggleDuty')` should be called as well?
        if Framework.GetPlayerJobName() == "police" or Framework.GetPlayerJobType() == "leo" then
            TriggerServerEvent("police:server:UpdateCurrentCops")
        end
        if (Framework.GetPlayerJobName() == "ambulance" or Framework.GetPlayerJobType() == "ems") and job then
            TriggerServerEvent('hospital:server:AddDoctor', 'ambulance')
        elseif (Framework.GetPlayerJobName() == "ambulance" or Framework.GetPlayerJobType() == "ems") and not job then
            TriggerServerEvent('hospital:server:RemoveDoctor', 'ambulance')
        end
        TriggerServerEvent("police:server:UpdateBlips")
    end
end)

RegisterNetEvent('police:SetCopCount', function(amount) -- CHECK: this probably should be removed since I didn't see any usage of it within the resource
    CurrentCops = amount
end)

