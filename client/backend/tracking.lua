local resourceName = tostring(GetCurrentResourceName())

RegisterNUICallback('getTracking', function(_, cb)
    if not MDTOpen then
        cb({ success = false, message = 'MDT is not open', data = {} })
        return
    end

    local tracking = ps.callback(resourceName .. ':server:getTracking')
    if tracking then
        cb({ success = true, data = tracking })
    else
        cb({ success = false, message = 'Failed to fetch tracking data', data = {} })
    end
end)

RegisterNetEvent(resourceName .. ':client:checkVehicleClass', function(netId, plate, coords, heading)
    local veh = NetworkGetEntityFromNetworkId(netId)
    if not veh or veh == 0 then return end

    if GetVehicleClass(veh) ~= 18 then return end

    TriggerServerEvent(resourceName .. ':server:cacheVehicle', plate, coords, heading)
end)