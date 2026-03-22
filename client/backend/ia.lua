local resourceName = tostring(GetCurrentResourceName())

local function OpenComplaintForm()
    SendNUIMessage({ action = 'showComplaintForm', data = {} })
    SetNuiFocus(true, true)
end

-- /complaint command
RegisterCommand('complaint', function()
    OpenComplaintForm()
end, false)

-- Export for other resources
exports('openComplaint', OpenComplaintForm)

-- Submit complaint (no MDTOpen check - standalone form)
RegisterNUICallback('submitComplaint', function(data, cb)
    if not data or not data.officerName or data.officerName == '' or not data.description or data.description == '' then
        cb({ success = false, message = 'Missing required fields' })
        return
    end

    local result = ps.callback(resourceName .. ':server:submitComplaint', data)
    cb(result or { success = false })
end)

-- Close complaint form
RegisterNUICallback('closeComplaint', function(data, cb)
    SetNuiFocus(false, false)
    cb({ success = true })
end)

RegisterNUICallback('getIAComplaints', function(data, cb)
    if not MDTOpen then
        cb({ complaints = {}, hasMore = false })
        return
    end

    data = data or {}
    local page = data.page or 1
    local filters = {
        status = data.status or nil,
        search = data.search or nil,
    }
    local result = ps.callback(resourceName .. ':server:getIAComplaints', page, filters)
    cb(result or { complaints = {}, hasMore = false })
end)

RegisterNUICallback('getIAComplaint', function(data, cb)
    if not MDTOpen then
        cb({ success = false, message = 'MDT is not open' })
        return
    end

    if not data or not data.id then
        cb({ success = false, message = 'Missing complaint ID' })
        return
    end

    local result = ps.callback(resourceName .. ':server:getIAComplaint', data.id)
    cb(result or { success = false })
end)

RegisterNUICallback('getIAHistoryForOfficer', function(data, cb)
    if not MDTOpen then cb({}) return end
    if not data or not data.officerName or data.officerName == '' then
        cb({})
        return
    end
    local result = ps.callback(resourceName .. ':server:getIAHistoryForOfficer', data.officerName)
    cb(result or {})
end)

RegisterNUICallback('updateIAComplaintInfo', function(data, cb)
    if not MDTOpen then cb({ success = false }) return end
    if not data or not data.id then
        cb({ success = false, message = 'Missing complaint ID' })
        return
    end
    local result = ps.callback(resourceName .. ':server:updateIAComplaintInfo', data.id, {
        officer_name = data.officer_name,
        officer_badge = data.officer_badge,
        incident_date = data.incident_date,
        incident_location = data.incident_location,
    })
    cb(result or { success = false })
end)

RegisterNUICallback('updateIAStatus', function(data, cb)
    if not MDTOpen then
        cb({ success = false, message = 'MDT is not open' })
        return
    end

    if not data or not data.id or not data.status then
        cb({ success = false, message = 'Missing complaint ID or status' })
        return
    end

    local result = ps.callback(resourceName .. ':server:updateIAStatus', data.id, data.status)
    cb(result or { success = false })
end)

RegisterNUICallback('assignIAComplaint', function(data, cb)
    if not MDTOpen then
        cb({ success = false, message = 'MDT is not open' })
        return
    end

    if not data or not data.id or not data.citizenid then
        cb({ success = false, message = 'Missing complaint ID or citizen ID' })
        return
    end

    local result = ps.callback(resourceName .. ':server:assignIAComplaint', data.id, data.citizenid)
    cb(result or { success = false })
end)

RegisterNUICallback('addIANote', function(data, cb)
    if not MDTOpen then cb({ success = false }) return end

    if not data or not data.complaintId or not data.content or data.content == '' then
        cb({ success = false, message = 'Missing complaint ID or note content' })
        return
    end

    local result = ps.callback(resourceName .. ':server:addIANote', data.complaintId, data.content)
    cb(result or { success = false })
end)

RegisterNUICallback('deleteIANote', function(data, cb)
    if not MDTOpen then cb({ success = false }) return end

    if not data or not data.noteId or not data.complaintId then
        cb({ success = false, message = 'Missing note ID or complaint ID' })
        return
    end

    local result = ps.callback(resourceName .. ':server:deleteIANote', data.noteId, data.complaintId)
    cb(result or { success = false })
end)
