local resourceName = tostring(GetCurrentResourceName())

RegisterNUICallback('getFTOList', function(data, cb)
    if not MDTOpen then cb({ entries = {}, hasMore = false }) return end
    data = data or {}
    local page = data.page or 1
    local filters = {
        status = data.status or nil,
        search = data.search or nil,
    }
    local result = ps.callback(resourceName .. ':server:getFTOList', page, filters)
    cb(result or { entries = {}, hasMore = false })
end)

RegisterNUICallback('getFTO', function(data, cb)
    if not MDTOpen then cb({ success = false }) return end
    if not data or not data.id then cb({ success = false }) return end
    local result = ps.callback(resourceName .. ':server:getFTO', data.id)
    cb(result or { success = false })
end)

RegisterNUICallback('getOfficerFTOHistory', function(data, cb)
    if not MDTOpen then cb({}) return end
    if not data or not data.officerCitizenId or data.officerCitizenId == '' then cb({}) return end
    local result = ps.callback(resourceName .. ':server:getOfficerFTOHistory', data.officerCitizenId)
    cb(result or {})
end)

RegisterNUICallback('createFTOAssignment', function(data, cb)
    if not MDTOpen then cb({ success = false }) return end
    if not data then cb({ success = false }) return end
    local result = ps.callback(resourceName .. ':server:createFTOAssignment', data)
    cb(result or { success = false })
end)

RegisterNUICallback('updateFTOAssignment', function(data, cb)
    if not MDTOpen then cb({ success = false }) return end
    if not data or not data.id then cb({ success = false }) return end
    local result = ps.callback(resourceName .. ':server:updateFTOAssignment', data.id, data.updates or {})
    cb(result or { success = false })
end)

RegisterNUICallback('deleteFTOAssignment', function(data, cb)
    if not MDTOpen then cb({ success = false }) return end
    if not data or not data.id then cb({ success = false }) return end
    local result = ps.callback(resourceName .. ':server:deleteFTOAssignment', data.id)
    cb(result or { success = false })
end)

RegisterNUICallback('createFTODor', function(data, cb)
    if not MDTOpen then cb({ success = false }) return end
    if not data then cb({ success = false }) return end
    local result = ps.callback(resourceName .. ':server:createFTODor', data)
    cb(result or { success = false })
end)

RegisterNUICallback('deleteFTODor', function(data, cb)
    if not MDTOpen then cb({ success = false }) return end
    if not data or not data.id then cb({ success = false }) return end
    local result = ps.callback(resourceName .. ':server:deleteFTODor', data.id)
    cb(result or { success = false })
end)

RegisterNUICallback('getFTOPhases', function(data, cb)
    if not MDTOpen then cb({}) return end
    local result = ps.callback(resourceName .. ':server:getFTOPhases')
    cb(result or {})
end)

RegisterNUICallback('saveFTOPhases', function(data, cb)
    if not MDTOpen then cb({ success = false }) return end
    if not data or not data.phases then cb({ success = false }) return end
    local result = ps.callback(resourceName .. ':server:saveFTOPhases', data.phases)
    cb(result or { success = false })
end)

RegisterNUICallback('getFTOCompetencies', function(data, cb)
    if not MDTOpen then cb({}) return end
    local result = ps.callback(resourceName .. ':server:getFTOCompetencies')
    cb(result or {})
end)

RegisterNUICallback('saveFTOCompetencies', function(data, cb)
    if not MDTOpen then cb({ success = false }) return end
    if not data or not data.competencies then cb({ success = false }) return end
    local result = ps.callback(resourceName .. ':server:saveFTOCompetencies', data.competencies)
    cb(result or { success = false })
end)
