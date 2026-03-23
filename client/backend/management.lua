local resourceName = tostring(GetCurrentResourceName())

RegisterNUICallback('getPermissionRoles', function(_, cb)
    if not MDTOpen then
        cb({ success = false, message = 'MDT is not open' })
        return
    end

    local result = ps.callback(resourceName .. ':server:getPermissionRoles')
    ps.debug('[getPermissionRoles] Result:', result)
    cb(result or { success = false, message = 'Failed to fetch roles' })
end)

RegisterNUICallback('updatePermissionRole', function(data, cb)
    if not MDTOpen then
        cb({ success = false, message = 'MDT is not open' })
        return
    end

    local result = ps.callback(resourceName .. ':server:updatePermissionRole', data or {})
    cb(result or { success = false, message = 'Failed to update role' })
end)

-- SETTINGS: Activity Tracking -------------------------------------------

RegisterNUICallback('getAuditTrackingConfig', function(_, cb)
    if not MDTOpen then
        cb({})
        return
    end

    local result = ps.callback(resourceName .. ':server:getAuditTrackingConfig')
    -- Server returns JSON string to preserve boolean false values through msgpack
    if type(result) == 'string' then
        local ok, decoded = pcall(json.decode, result)
        if ok then
            cb(decoded)
            return
        end
    end
    cb(result or {})
end)

RegisterNUICallback('saveAuditTrackingConfig', function(data, cb)
    if not MDTOpen then
        cb({ success = false, message = 'MDT is not open' })
        return
    end

    -- Encode as JSON string to preserve boolean false values through msgpack serialization
    local result = ps.callback(resourceName .. ':server:saveAuditTrackingConfig', json.encode(data or {}))
    cb(result or { success = false, message = 'Failed to save settings' })
end)

-- SETTINGS: Jail / Fines -------------------------------------------

RegisterNUICallback('getJailFinesConfig', function(_, cb)
    if not MDTOpen then
        cb({})
        return
    end

    local result = ps.callback(resourceName .. ':server:getJailFinesConfig')
    cb(result or {})
end)

RegisterNUICallback('saveJailFinesConfig', function(data, cb)
    if not MDTOpen then
        cb({ success = false, message = 'MDT is not open' })
        return
    end

    local result = ps.callback(resourceName .. ':server:saveJailFinesConfig', data or {})
    cb(result or { success = false, message = 'Failed to save settings' })
end)

-- SETTINGS: Report Templates -------------------------------------------

RegisterNUICallback('getReportTemplates', function(data, cb)
    if not MDTOpen then
        cb({})
        return
    end

    local jobType = (type(data) == 'table' and data.jobType) or nil
    local result = ps.callback(resourceName .. ':server:getReportTemplates', { jobType = jobType })
    cb(result or {})
end)

RegisterNUICallback('saveReportTemplate', function(data, cb)
    if not MDTOpen then
        cb({ success = false, message = 'MDT is not open' })
        return
    end

    local result = ps.callback(resourceName .. ':server:saveReportTemplate', data or {})
    cb(result or { success = false, message = 'Failed to save template' })
end)

RegisterNUICallback('deleteReportTemplate', function(data, cb)
    if not MDTOpen then
        cb({ success = false, message = 'MDT is not open' })
        return
    end

    local result = ps.callback(resourceName .. ':server:deleteReportTemplate', data or {})
    cb(result or { success = false, message = 'Failed to delete template' })
end)

-- TAG MANAGEMENT -------------------------------------------

RegisterNUICallback('getTags', function(data, cb)
    if not MDTOpen then
        cb({})
        return
    end
    local jobType = (type(data) == 'table' and data.jobType) or nil
    local result = ps.callback(resourceName .. ':server:getTags', { jobType = jobType })
    cb(result or {})
end)

RegisterNUICallback('createTag', function(data, cb)
    if not MDTOpen then
        cb({ success = false, message = 'MDT is not open' })
        return
    end
    local result = ps.callback(resourceName .. ':server:createTag', data or {})
    cb(result or { success = false, message = 'Failed to create tag' })
end)

RegisterNUICallback('updateTag', function(data, cb)
    if not MDTOpen then
        cb({ success = false, message = 'MDT is not open' })
        return
    end
    local result = ps.callback(resourceName .. ':server:updateTag', data or {})
    cb(result or { success = false, message = 'Failed to update tag' })
end)

RegisterNUICallback('deleteTag', function(data, cb)
    if not MDTOpen then
        cb({ success = false, message = 'MDT is not open' })
        return
    end
    local result = ps.callback(resourceName .. ':server:deleteTag', data or {})
    cb(result or { success = false, message = 'Failed to delete tag' })
end)

-- SETTINGS: Awards -------------------------------------------

RegisterNUICallback('getAwardConfigs', function(_, cb)
    if not MDTOpen then
        cb({})
        return
    end
    local result = ps.callback(resourceName .. ':server:getAwardConfigs')
    cb(result or {})
end)

RegisterNUICallback('saveAward', function(data, cb)
    if not MDTOpen then
        cb({ success = false, message = 'MDT is not open' })
        return
    end
    local result = ps.callback(resourceName .. ':server:saveAward', data or {})
    cb(result or { success = false, message = 'Failed to save award' })
end)

RegisterNUICallback('deleteAward', function(data, cb)
    if not MDTOpen then
        cb({ success = false, message = 'MDT is not open' })
        return
    end
    local result = ps.callback(resourceName .. ':server:deleteAward', data or {})
    cb(result or { success = false, message = 'Failed to delete award' })
end)

-- AWARDS PAGE: Get awards data (stats + progress + leaderboard) ---

RegisterNUICallback('getAwardsData', function(data, cb)
    if not MDTOpen then
        cb(nil)
        return
    end
    local result = ps.callback(resourceName .. ':server:getAwardsData', data or {})
    cb(result)
end)

-- SETTINGS: Custom Licenses -------------------------------------------

RegisterNUICallback('getCustomLicenses', function(_, cb)
    if not MDTOpen then
        cb({})
        return
    end
    local result = ps.callback(resourceName .. ':server:getCustomLicenses')
    cb(result or {})
end)

RegisterNUICallback('saveCustomLicense', function(data, cb)
    if not MDTOpen then
        cb({ success = false, message = 'MDT is not open' })
        return
    end
    local result = ps.callback(resourceName .. ':server:saveCustomLicense', data or {})
    cb(result or { success = false, message = 'Failed to save license' })
end)

RegisterNUICallback('deleteCustomLicense', function(data, cb)
    if not MDTOpen then
        cb({ success = false, message = 'MDT is not open' })
        return
    end
    local result = ps.callback(resourceName .. ':server:deleteCustomLicense', data or {})
    cb(result or { success = false, message = 'Failed to delete license' })
end)

-- SETTINGS: Colors -------------------------------------------

RegisterNUICallback('getColorConfig', function(_, cb)
    if not MDTOpen then
        cb(nil)
        return
    end
    local result = ps.callback(resourceName .. ':server:getColorConfig')
    cb(result)
end)

RegisterNUICallback('saveColorConfig', function(data, cb)
    if not MDTOpen then
        cb({ success = false, message = 'MDT is not open' })
        return
    end
    local result = ps.callback(resourceName .. ':server:saveColorConfig', data or {})
    cb(result or { success = false, message = 'Failed to save colors' })
end)
