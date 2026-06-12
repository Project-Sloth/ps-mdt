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

RegisterNUICallback('setHearingStatus', function(data, cb)
    if not MDTOpen then cb({ success = false, error = 'MDT is not open' }) return end
    local result = ps.callback(resourceName .. ':server:setHearingStatus', {
        hearingId = data and data.hearingId,
        status    = data and data.status,
    })
    cb(result or { success = false, error = 'Failed to set status' })
end)

RegisterNUICallback('getAttendeeGroups', function(data, cb)
    if not MDTOpen then cb({}) return end
    local result = ps.callback(resourceName .. ':server:getAttendeeGroups', {})
    cb(result or {})
end)

RegisterNUICallback('getGroupMembers', function(data, cb)
    if not MDTOpen then cb({ success = false }) return end
    local result = ps.callback(resourceName .. ':server:getGroupMembers', {
        groupId = data and data.groupId,
    })
    cb(result or { success = false })
end)

RegisterNUICallback('addHearingAttendeesBulk', function(data, cb)
    if not MDTOpen then cb({ success = false }) return end
    local result = ps.callback(resourceName .. ':server:addHearingAttendeesBulk', {
        hearingId = data and data.hearingId,
        attendees = data and data.attendees,
    })
    cb(result or { success = false })
end)

RegisterNUICallback('getMissedHearings', function(data, cb)
    if not MDTOpen then cb({}) return end
    local result = ps.callback(resourceName .. ':server:getMissedHearings', {})
    cb(result or {})
end)

-- ============================================================================
--  Reminders are now delivered as lb-phone SMS from the server (see
--  server/backend/court.lua). No in-MDT reminder push is needed anymore.
-- ============================================================================