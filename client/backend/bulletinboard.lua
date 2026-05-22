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

-- Delete a bulletin post (soft delete)
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