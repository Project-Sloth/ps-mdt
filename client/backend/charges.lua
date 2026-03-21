local resourceName = tostring(GetCurrentResourceName())

RegisterNUICallback('getCharges', function(data, cb)
    if not MDTOpen then cb({}) return end
    local callbacks = ps.callback('ps-mdt:getChargeList', false)
    cb(callbacks)
end)

RegisterNUICallback('processFine', function(data, cb)
    if not MDTOpen then
        cb({ success = false, message = 'MDT is not open' })
        return
    end

    if type(data) ~= 'table' or not data.citizenid or not data.fine then
        cb({ success = false, message = 'Missing citizen ID or fine amount' })
        return
    end

    local result = ps.callback(resourceName .. ':server:processFine', data)
    cb(result or { success = false, message = 'Failed to process fine' })
end)

RegisterNUICallback('updateCharge', function(data, cb)
    if not MDTOpen then
        cb({ success = false, message = 'MDT is not open' })
        return
    end

    if type(data) ~= 'table' or not data.code then
        cb({ success = false, message = 'Missing charge code' })
        return
    end

    local result = ps.callback(resourceName .. ':server:updateCharge', data)
    cb(result or { success = false, message = 'Failed to update charge' })
end)
