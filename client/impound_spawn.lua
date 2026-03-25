local resourceName = tostring(GetCurrentResourceName())
local QBCore = exports['qb-core']:GetCoreObject()

-- Impound locations - override in config if needed
local ImpoundLocations = Config.ImpoundLocations or {
    [1] = vector4(409.09, -1623.37, 29.29, 232.07),
    [2] = vector4(-436.42, 5982.29, 31.34, 136.0),
}

-- Apply damage to vehicle based on stored damage values
local function doCarDamage(currentVehicle, veh)
    local smash = false
    local damageOutside = false
    local damageOutside2 = false
    local engine = (veh.engine or 1000.0) + 0.0
    local body = (veh.body or 1000.0) + 0.0

    if engine < 200.0 then engine = 200.0 end
    if engine > 1000.0 then engine = 950.0 end
    if body < 150.0 then body = 150.0 end
    if body < 950.0 then smash = true end
    if body < 920.0 then damageOutside = true end
    if body < 920.0 then damageOutside2 = true end

    Wait(100)
    SetVehicleEngineHealth(currentVehicle, engine)

    if smash then
        for i = 0, 4 do
            SmashVehicleWindow(currentVehicle, i)
        end
    end

    if damageOutside then
        SetVehicleDoorBroken(currentVehicle, 1, true)
        SetVehicleDoorBroken(currentVehicle, 6, true)
        SetVehicleDoorBroken(currentVehicle, 4, true)
    end

    if damageOutside2 then
        for i = 1, 4 do
            SetVehicleTyreBurst(currentVehicle, i, false, 990.0)
        end
    end

    if body < 1000 then
        SetVehicleBodyHealth(currentVehicle, 985.1)
    end
end

-- Spawn vehicle at impound location
local function TakeOutImpound(data, garageIndex)
    local coords = ImpoundLocations[garageIndex]
    if not coords then
        ps.notify('Invalid impound location', 'error')
        return
    end

    QBCore.Functions.SpawnVehicle(data.vehicle, function(veh)
        -- Try to get and apply stored vehicle properties
        QBCore.Functions.TriggerCallback('qb-garage:server:GetVehicleProperties', function(properties)
            if properties then
                QBCore.Functions.SetVehicleProperties(veh, properties)
            end
            SetVehicleNumberPlateText(veh, data.plate)
            SetEntityHeading(veh, coords.w or 0.0)

            -- Set fuel
            local fuelExport = Config.Fuel or 'LegacyFuel'
            if GetResourceState(fuelExport) == 'started' then
                pcall(function()
                    exports[fuelExport]:SetFuel(veh, data.fuel or 100.0)
                end)
            end

            -- Apply damage
            doCarDamage(veh, data)

            -- Give keys to owner
            pcall(function()
                TriggerEvent('vehiclekeys:client:SetOwner', QBCore.Functions.GetPlate(veh))
            end)

            SetVehicleEngineOn(veh, true, true)
        end, data.plate)
    end, coords, true)
end

-- Event: Vehicle released from impound, spawn it
RegisterNetEvent(resourceName .. ':client:TakeOutImpound', function(data)
    if not data then return end

    local pos = GetEntityCoords(PlayerPedId())
    local garageIndex = data.currentSelection or 1
    local impoundCoords = ImpoundLocations[garageIndex]

    if not impoundCoords then
        ps.notify('Invalid impound location', 'error')
        return
    end

    local takeDist = vector3(impoundCoords.x, impoundCoords.y, impoundCoords.z)
    if #(pos - takeDist) <= 15.0 then
        TakeOutImpound(data, garageIndex)
    else
        ps.notify('You are too far away from the impound location!', 'error')
    end
end)

-- Also listen for the v1 event name for backwards compatibility
RegisterNetEvent('ps-mdt:client:TakeOutImpound', function(data)
    TriggerEvent(resourceName .. ':client:TakeOutImpound', data)
end)
