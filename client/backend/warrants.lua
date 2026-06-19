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

-- Live update pushed by the server whenever a warrant is issued, closed or
-- approved. Gated to LEO so we don't hand law-enforcement data to other NUIs.
RegisterNetEvent(resourceName .. ':client:updateActiveWarrants', function(data)
    if ps.getJobType() == 'leo' then
        SendNUI('updateActiveWarrants', data or {})
    end
end)