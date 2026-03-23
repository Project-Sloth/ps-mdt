local resourceName = tostring(GetCurrentResourceName())

-- Get all SOP categories with sections
RegisterNUICallback('getSOPCategories', function(data, cb)
    local result = ps.callback(resourceName .. ':server:getSOPCategories')
    cb(result or {})
end)

-- Create a SOP category
RegisterNUICallback('createSOPCategory', function(data, cb)
    if not data then cb({ success = false }) return end
    local result = ps.callback(resourceName .. ':server:createSOPCategory', data)
    cb(result or { success = false })
end)

-- Update a SOP category
RegisterNUICallback('updateSOPCategory', function(data, cb)
    if not data or not data.id then cb({ success = false }) return end
    local categoryId = data.id
    data.id = nil
    local result = ps.callback(resourceName .. ':server:updateSOPCategory', categoryId, data)
    cb(result or { success = false })
end)

-- Delete a SOP category
RegisterNUICallback('deleteSOPCategory', function(data, cb)
    if not data or not data.id then cb({ success = false }) return end
    local result = ps.callback(resourceName .. ':server:deleteSOPCategory', data.id)
    cb(result or { success = false })
end)

-- Create a SOP section
RegisterNUICallback('createSOPSection', function(data, cb)
    if not data then cb({ success = false }) return end
    local result = ps.callback(resourceName .. ':server:createSOPSection', data)
    cb(result or { success = false })
end)

-- Update a SOP section
RegisterNUICallback('updateSOPSection', function(data, cb)
    if not data or not data.id then cb({ success = false }) return end
    local sectionId = data.id
    data.id = nil
    local result = ps.callback(resourceName .. ':server:updateSOPSection', sectionId, data)
    cb(result or { success = false })
end)

-- Delete a SOP section
RegisterNUICallback('deleteSOPSection', function(data, cb)
    if not data or not data.id then cb({ success = false }) return end
    local result = ps.callback(resourceName .. ':server:deleteSOPSection', data.id)
    cb(result or { success = false })
end)

-- Get SOP settings (intro + version)
RegisterNUICallback('getSOPSettings', function(data, cb)
    local result = ps.callback(resourceName .. ':server:getSOPSettings')
    cb(result or {})
end)

-- Update SOP mission statement
RegisterNUICallback('updateSOPMission', function(data, cb)
    if not data then cb({ success = false }) return end
    local result = ps.callback(resourceName .. ':server:updateSOPMission', data.mission_statement or '')
    cb(result or { success = false })
end)

-- Update SOP introduction
RegisterNUICallback('updateSOPIntro', function(data, cb)
    if not data then cb({ success = false }) return end
    local result = ps.callback(resourceName .. ':server:updateSOPIntro', data.introduction or '')
    cb(result or { success = false })
end)

-- Publish SOP (bump version)
RegisterNUICallback('publishSOP', function(data, cb)
    local result = ps.callback(resourceName .. ':server:publishSOP')
    cb(result or { success = false })
end)

-- Check SOP agreement status
RegisterNUICallback('checkSOPAgreement', function(data, cb)
    local result = ps.callback(resourceName .. ':server:checkSOPAgreement')
    cb(result or { agreed = true })
end)

-- Acknowledge SOP
RegisterNUICallback('acknowledgesSOP', function(data, cb)
    local result = ps.callback(resourceName .. ':server:acknowledgesSOP')
    cb(result or { success = false })
end)
