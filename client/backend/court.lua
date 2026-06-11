local resourceName = tostring(GetCurrentResourceName())

-- ============================================================================
--  NUI -> Server bridges
-- ============================================================================

RegisterNUICallback('getHearings', function(data, cb)
    if not MDTOpen then cb({}) return end
    local result = ps.callback(resourceName .. ':server:getHearings', {
        from = data and data.from,
        to   = data and data.to,
    })
    cb(result or {})
end)

RegisterNUICallback('getHearing', function(data, cb)
    if not MDTOpen then cb({ success = false }) return end
    local result = ps.callback(resourceName .. ':server:getHearing', {
        hearingId = data and data.hearingId,
    })
    cb(result or { success = false })
end)

RegisterNUICallback('createHearing', function(data, cb)
    if not MDTOpen then cb({ success = false, error = 'MDT is not open' }) return end
    local result = ps.callback(resourceName .. ':server:createHearing', data or {})
    cb(result or { success = false, error = 'Failed to create hearing' })
end)

RegisterNUICallback('updateHearing', function(data, cb)
    if not MDTOpen then cb({ success = false, error = 'MDT is not open' }) return end
    local result = ps.callback(resourceName .. ':server:updateHearing', {
        hearingId = data and data.hearingId,
        data      = data and data.data,
    })
    cb(result or { success = false, error = 'Failed to update hearing' })
end)

RegisterNUICallback('deleteHearing', function(data, cb)
    if not MDTOpen then cb({ success = false, error = 'MDT is not open' }) return end
    local result = ps.callback(resourceName .. ':server:deleteHearing', {
        hearingId = data and data.hearingId,
    })
    cb(result or { success = false, error = 'Failed to delete hearing' })
end)

RegisterNUICallback('addHearingAttendee', function(data, cb)
    if not MDTOpen then cb({ success = false }) return end
    local result = ps.callback(resourceName .. ':server:addHearingAttendee', data or {})
    cb(result or { success = false })
end)

RegisterNUICallback('removeHearingAttendee', function(data, cb)
    if not MDTOpen then cb({ success = false }) return end
    local result = ps.callback(resourceName .. ':server:removeHearingAttendee', {
        attendeeId = data and data.attendeeId,
    })
    cb(result or { success = false })
end)

-- ============================================================================
--  Server -> NUI live reminder push
-- ============================================================================

RegisterNetEvent(resourceName .. ':client:courtReminder', function(data)
    if MDTOpen then
        SendNUI('courtReminder', data)
    end
end)
