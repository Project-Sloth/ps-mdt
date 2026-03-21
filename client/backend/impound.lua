-- Impound NUI callbacks - bridge between Svelte UI and server

local resourceName = tostring(GetCurrentResourceName())

RegisterNUICallback('impoundVehicle', function(data, cb)
    if not MDTOpen then
        cb({ success = false, message = 'MDT is not open' })
        return
    end

    if type(data) ~= 'table' or not data.plate then
        cb({ success = false, message = 'Missing plate number' })
        return
    end

    local result = ps.callback(resourceName .. ':server:impoundVehicle', data)
    cb(result or { success = false, message = 'Failed to impound vehicle' })
end)

RegisterNUICallback('releaseImpound', function(data, cb)
    if not MDTOpen then
        cb({ success = false, message = 'MDT is not open' })
        return
    end

    if type(data) ~= 'table' or not data.plate then
        cb({ success = false, message = 'Missing plate number' })
        return
    end

    local result = ps.callback(resourceName .. ':server:releaseImpound', data)
    cb(result or { success = false, message = 'Failed to release vehicle' })
end)

RegisterNUICallback('getImpoundStatus', function(data, cb)
    if not MDTOpen then
        cb({ success = false, message = 'MDT is not open' })
        return
    end

    if type(data) ~= 'table' or not data.plate then
        cb({ success = false, message = 'Missing plate number' })
        return
    end

    local result = ps.callback(resourceName .. ':server:getImpoundStatus', data)
    cb(result or { success = false })
end)
