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
