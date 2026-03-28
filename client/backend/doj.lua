local resourceName = tostring(GetCurrentResourceName())

-- Court Cases
RegisterNUICallback('getCourtCases', function(data, cb)
    if not MDTOpen then
        cb({ cases = {}, total = 0 })
        return
    end

    data = data or {}
    local result = ps.callback(
        resourceName .. ':server:getCourtCases',
        data.page or 1,
        data.limit or 20,
        data.status or 'all',
        data.case_type or 'all',
        data.search or ''
    )
    cb(result or { cases = {}, total = 0 })
end)

RegisterNUICallback('getCourtCase', function(data, cb)
    if not MDTOpen then
        cb(nil)
        return
    end

    if not data or not data.id then
        cb(nil)
        return
    end

    local result = ps.callback(resourceName .. ':server:getCourtCase', data.id)
    cb(result)
end)

RegisterNUICallback('createCourtCase', function(data, cb)
    if not MDTOpen then
        cb({ success = false, message = 'MDT is not open' })
        return
    end

    local result = ps.callback(resourceName .. ':server:createCourtCase', data or {})
    cb(result or { success = false })
end)

RegisterNUICallback('updateCourtCase', function(data, cb)
    if not MDTOpen then
        cb({ success = false, message = 'MDT is not open' })
        return
    end

    if not data or not data.id then
        cb({ success = false, message = 'Missing case ID' })
        return
    end

    local result = ps.callback(resourceName .. ':server:updateCourtCase', data.id, data.payload or {})
    cb(result or { success = false })
end)

-- Warrant Requests
RegisterNUICallback('getWarrantRequests', function(data, cb)
    if not MDTOpen then
        cb({ requests = {}, total = 0 })
        return
    end

    data = data or {}
    local result = ps.callback(
        resourceName .. ':server:getWarrantRequests',
        data.page or 1,
        data.limit or 20,
        data.status or 'all'
    )
    cb(result or { requests = {}, total = 0 })
end)

RegisterNUICallback('createWarrantRequest', function(data, cb)
    if not MDTOpen then
        cb({ success = false, message = 'MDT is not open' })
        return
    end

    local result = ps.callback(resourceName .. ':server:createWarrantRequest', data or {})
    cb(result or { success = false })
end)

RegisterNUICallback('reviewWarrantRequest', function(data, cb)
    if not MDTOpen then
        cb({ success = false, message = 'MDT is not open' })
        return
    end

    if not data or not data.request_id or not data.decision then
        cb({ success = false, message = 'Missing request_id or decision' })
        return
    end

    local result = ps.callback(
        resourceName .. ':server:reviewWarrantRequest',
        data.request_id,
        data.decision,
        data.reason or ''
    )
    cb(result or { success = false })
end)

-- Court Orders
RegisterNUICallback('getCourtOrders', function(data, cb)
    if not MDTOpen then
        cb({ orders = {}, total = 0 })
        return
    end

    data = data or {}
    local result = ps.callback(
        resourceName .. ':server:getCourtOrders',
        data.page or 1,
        data.limit or 20,
        data.type or 'all',
        data.status or 'all'
    )
    cb(result or { orders = {}, total = 0 })
end)

RegisterNUICallback('createCourtOrder', function(data, cb)
    if not MDTOpen then
        cb({ success = false, message = 'MDT is not open' })
        return
    end

    local result = ps.callback(resourceName .. ':server:createCourtOrder', data or {})
    cb(result or { success = false })
end)

RegisterNUICallback('updateCourtOrder', function(data, cb)
    if not MDTOpen then
        cb({ success = false, message = 'MDT is not open' })
        return
    end

    if not data or not data.id then
        cb({ success = false, message = 'Missing order ID' })
        return
    end

    local result = ps.callback(resourceName .. ':server:updateCourtOrder', data.id, data.payload or {})
    cb(result or { success = false })
end)

RegisterNUICallback('revokeCourtOrder', function(data, cb)
    if not MDTOpen then
        cb({ success = false, message = 'MDT is not open' })
        return
    end

    if not data or not data.id then
        cb({ success = false, message = 'Missing order ID' })
        return
    end

    local result = ps.callback(resourceName .. ':server:revokeCourtOrder', data.id)
    cb(result or { success = false })
end)

-- Legal Documents
RegisterNUICallback('getLegalDocuments', function(data, cb)
    if not MDTOpen then
        cb({ documents = {}, total = 0 })
        return
    end

    data = data or {}
    local result = ps.callback(
        resourceName .. ':server:getLegalDocuments',
        data.page or 1,
        data.limit or 20,
        data.type or 'all',
        data.status or 'all'
    )
    cb(result or { documents = {}, total = 0 })
end)

RegisterNUICallback('getLegalDocument', function(data, cb)
    if not MDTOpen then
        cb(nil)
        return
    end

    if not data or not data.id then
        cb(nil)
        return
    end

    local result = ps.callback(resourceName .. ':server:getLegalDocument', data.id)
    cb(result)
end)

RegisterNUICallback('createLegalDocument', function(data, cb)
    if not MDTOpen then
        cb({ success = false, message = 'MDT is not open' })
        return
    end

    local result = ps.callback(resourceName .. ':server:createLegalDocument', data or {})
    cb(result or { success = false })
end)

RegisterNUICallback('updateLegalDocument', function(data, cb)
    if not MDTOpen then
        cb({ success = false, message = 'MDT is not open' })
        return
    end

    if not data or not data.id then
        cb({ success = false, message = 'Missing document ID' })
        return
    end

    local result = ps.callback(resourceName .. ':server:updateLegalDocument', data.id, data.payload or {})
    cb(result or { success = false })
end)

RegisterNUICallback('deleteLegalDocument', function(data, cb)
    if not MDTOpen then
        cb({ success = false, message = 'MDT is not open' })
        return
    end

    if not data or not data.id then
        cb({ success = false, message = 'Missing document ID' })
        return
    end

    local result = ps.callback(resourceName .. ':server:deleteLegalDocument', data.id)
    cb(result or { success = false })
end)

-- DOJ Dashboard
RegisterNUICallback('getDojDashboard', function(data, cb)
    if not MDTOpen then
        cb({})
        return
    end

    local result = ps.callback(resourceName .. ':server:getDojDashboard')
    cb(result or {})
end)
