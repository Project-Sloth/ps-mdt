local resourceName = tostring(GetCurrentResourceName())

-- Get paginated PPR list
RegisterNUICallback('getPPRList', function(data, cb)
    if not MDTOpen then cb({ entries = {}, hasMore = false }) return end

    data = data or {}
    local page = data.page or 1
    local filters = {
        category = data.category or nil,
        search = data.search or nil,
    }
    local result = ps.callback(resourceName .. ':server:getPPRList', page, filters)
    cb(result or { entries = {}, hasMore = false })
end)

-- Get single PPR entry with notes
RegisterNUICallback('getPPR', function(data, cb)
    if not MDTOpen then cb({ success = false }) return end
    if not data or not data.id then
        cb({ success = false, message = 'Missing PPR ID' })
        return
    end
    local result = ps.callback(resourceName .. ':server:getPPR', data.id)
    cb(result or { success = false })
end)

-- Get PPR history for a specific officer
RegisterNUICallback('getOfficerPPRHistory', function(data, cb)
    if not MDTOpen then cb({}) return end
    if not data or not data.officerCitizenId or data.officerCitizenId == '' then
        cb({})
        return
    end
    local result = ps.callback(resourceName .. ':server:getOfficerPPRHistory', data.officerCitizenId)
    cb(result or {})
end)

-- Create a new PPR entry
RegisterNUICallback('createPPR', function(data, cb)
    if not MDTOpen then cb({ success = false }) return end
    if not data then
        cb({ success = false, message = 'Missing data' })
        return
    end
    local result = ps.callback(resourceName .. ':server:createPPR', data)
    cb(result or { success = false })
end)

-- Update a PPR entry
RegisterNUICallback('updatePPR', function(data, cb)
    if not MDTOpen then cb({ success = false }) return end
    if not data or not data.id then
        cb({ success = false, message = 'Missing PPR ID' })
        return
    end
    local pprId = data.id
    data.id = nil
    local result = ps.callback(resourceName .. ':server:updatePPR', pprId, data)
    cb(result or { success = false })
end)

-- Delete a PPR entry
RegisterNUICallback('deletePPR', function(data, cb)
    if not MDTOpen then cb({ success = false }) return end
    if not data or not data.id then
        cb({ success = false, message = 'Missing PPR ID' })
        return
    end
    local result = ps.callback(resourceName .. ':server:deletePPR', data.id)
    cb(result or { success = false })
end)

-- Add a note to a PPR entry
RegisterNUICallback('addPPRNote', function(data, cb)
    if not MDTOpen then cb({ success = false }) return end
    if not data or not data.pprId or not data.content or data.content == '' then
        cb({ success = false, message = 'Missing PPR ID or note content' })
        return
    end
    local result = ps.callback(resourceName .. ':server:addPPRNote', data.pprId, data.content)
    cb(result or { success = false })
end)

-- Delete a PPR note
RegisterNUICallback('deletePPRNote', function(data, cb)
    if not MDTOpen then cb({ success = false }) return end
    if not data or not data.noteId or not data.pprId then
        cb({ success = false, message = 'Missing note ID or PPR ID' })
        return
    end
    local result = ps.callback(resourceName .. ':server:deletePPRNote', data.noteId, data.pprId)
    cb(result or { success = false })
end)
