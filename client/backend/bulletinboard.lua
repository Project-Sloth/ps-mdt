local resourceName = tostring(GetCurrentResourceName())

-- Get all bulletin posts for the officer's department
RegisterNUICallback('getBulletinPosts', function(data, cb)
    local result = ps.callback(resourceName .. ':server:getBulletinPosts')
    cb(result or {})
end)

-- Create a new bulletin post
RegisterNUICallback('createBulletinPost', function(data, cb)
    if not data then cb({ success = false }) return end
    local result = ps.callback(resourceName .. ':server:createBulletinPost', data)
    cb(result or { success = false })
end)

-- Update an existing bulletin post
RegisterNUICallback('updateBulletinPost', function(data, cb)
    if not data or not data.id then cb({ success = false }) return end
    local postId = data.id
    data.id = nil
    local result = ps.callback(resourceName .. ':server:updateBulletinPost', postId, data)
    cb(result or { success = false })
end)

-- Delete a bulletin post
RegisterNUICallback('deleteBulletinPost', function(data, cb)
    if not data or not data.id then cb({ success = false }) return end
    local result = ps.callback(resourceName .. ':server:deleteBulletinPost', data.id)
    cb(result or { success = false })
end)

-- Toggle pin on a bulletin post (supervisor only)
RegisterNUICallback('toggleBulletinPin', function(data, cb)
    if not data or not data.id then cb({ success = false }) return end
    local result = ps.callback(resourceName .. ':server:toggleBulletinPin', data.id)
    cb(result or { success = false })
end)

-- ── Category management ───────────────────────────────────────

-- Get all categories for the current job
RegisterNUICallback('getBulletinCategories', function(data, cb)
    local result = ps.callback(resourceName .. ':server:getBulletinCategories')
    cb(result or {})
end)

-- Add a new category
RegisterNUICallback('addBulletinCategory', function(data, cb)
    if not data or not data.label or data.label == '' then
        cb({ success = false, error = 'Missing required fields' })
        return
    end
    local result = ps.callback(resourceName .. ':server:addBulletinCategory', data)
    cb(result or { success = false })
end)

-- Update an existing category (label, icon, color, sort_order)
RegisterNUICallback('updateBulletinCategory', function(data, cb)
    if not data or not data.value then
        cb({ success = false, error = 'Missing category value' })
        return
    end
    local result = ps.callback(resourceName .. ':server:updateBulletinCategory', data)
    cb(result or { success = false })
end)

-- Remove a category by value
RegisterNUICallback('removeBulletinCategory', function(data, cb)
    if not data or not data.value then
        cb({ success = false, error = 'Missing category value' })
        return
    end
    local result = ps.callback(resourceName .. ':server:removeBulletinCategory', data)
    cb(result or { success = false })
end)

-- Reorder categories (bulk sort_order update)
RegisterNUICallback('reorderBulletinCategories', function(data, cb)
    if not data or not data.order then
        cb({ success = false, error = 'Missing order data' })
        return
    end
    -- Pass the whole data table so server can read data.order reliably
    local result = ps.callback(resourceName .. ':server:reorderBulletinCategories', data)
    cb(result or { success = false })
end)