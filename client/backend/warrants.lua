local resourceName = tostring(GetCurrentResourceName())

RegisterNUICallback('issueWarrant', function(data, cb)
    if not MDTOpen then
        cb({ success = false, message = 'MDT is not open' })
        return
    end

    local result = ps.callback(resourceName .. ':server:issueWarrant', data or {})
    if result and result.success then
        cb({ success = true })
    else
        cb({ success = false, message = result and result.error or 'Failed to issue warrant' })
    end
end)

RegisterNUICallback('closeWarrant', function(data, cb)
    if not MDTOpen then
        cb({ success = false, message = 'MDT is not open' })
        return
    end

    local result = ps.callback(resourceName .. ':server:closeWarrant', data or {})
    if result and result.success then
        cb({ success = true })
    else
        cb({ success = false, message = result and result.error or 'Failed to close warrant' })
    end
end)
