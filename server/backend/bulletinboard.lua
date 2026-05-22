local resourceName = tostring(GetCurrentResourceName())

-- ── Get all bulletin posts for the officer's department ──────

ps.registerCallback(resourceName .. ':server:getBulletinPosts', function(source)
    local src = source
    if not CheckAuth(src) then return {} end

    local jobName = ps.getJobName(src)
    if not jobName or jobName == '' then return {} end

    local ok, posts = pcall(MySQL.query.await, [[
        SELECT
            id, title, content, author, author_rank,
            category, priority, pinned, created_by,
            created_at, updated_at
        FROM mdt_bulletin_posts
        WHERE job = ?
        ORDER BY pinned DESC, FIELD(priority, 'urgent', 'high', 'normal', 'low'), created_at DESC
    ]], { jobName })

    if not ok or not posts then return {} end

    -- Convert tinyint pinned → boolean for JSON
    for _, post in ipairs(posts) do
        post.pinned = post.pinned == 1 or post.pinned == "1" or post.pinned == true
    end

    return posts
end)

-- ── Create a bulletin post ────────────────────────────────────

ps.registerCallback(resourceName .. ':server:createBulletinPost', function(source, data)
    local src = source
    if not CheckAuth(src) then return { success = false, error = 'Unauthorized' } end
    if not CheckPermission(src, 'bulletin_post') then
        return { success = false, error = 'No permission to create bulletin posts' }
    end

    data = data or {}

    local VALID_CATEGORIES = { announcement = true, operations = true, training = true, general = true, warrants = true }
    local VALID_PRIORITIES  = { low = true, normal = true, high = true, urgent = true }

    local title = tostring(data.title or ''):gsub('^%s+', ''):gsub('%s+$', '')
    if title == '' then return { success = false, error = 'Title is required' } end
    if not VALID_CATEGORIES[data.category] then return { success = false, error = 'Invalid category' } end
    if not VALID_PRIORITIES[data.priority]  then return { success = false, error = 'Invalid priority'  } end

    local jobName   = ps.getJobName(src)
    local jobRank   = ps.getJobGradeName(src)
    local citizenId = ps.getIdentifier(src)

    -- Resolve author name + rank from profile
    local profile = MySQL.single.await('SELECT fullname FROM mdt_profiles WHERE citizenid = ?', { citizenId })
    local author  = (profile and profile.fullname) or tostring(GetPlayerName(src) or 'Unknown')

    -- Only supervisors may pin
    local canPin = CheckPermission(src, 'bulletin_pin')
    local pinned = (canPin and data.pinned == true) and 1 or 0

    local id = MySQL.insert.await([[
        INSERT INTO mdt_bulletin_posts
            (title, content, author, author_rank, category, priority, pinned, job, created_by)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
    ]], {
        title:sub(1, 255),
        tostring(data.content or ''):sub(1, 65535),
        author:sub(1, 100),
        jobRank,
        data.category,
        data.priority,
        pinned,
        jobName,
        citizenId
    })

    if not id then return { success = false, error = 'Database error' } end
    return { success = true, id = id }
end)

-- ── Update a bulletin post ────────────────────────────────────

ps.registerCallback(resourceName .. ':server:updateBulletinPost', function(source, postId, updates)
    local src = source
    if not CheckAuth(src) then return { success = false, error = 'Unauthorized' } end

    postId  = tonumber(postId)
    updates = updates or {}
    if not postId then return { success = false, error = 'Invalid post id' } end

    -- Fetch post to verify ownership / permission
    local existing = MySQL.single.await(
        'SELECT created_by, job FROM mdt_bulletin_posts WHERE id = ?',
        { postId }
    )
    if not existing then return { success = false, error = 'Post not found' } end

    local jobName   = ps.getJobName(src)
    local citizenId = ps.getIdentifier(src)
    local isSupervisor = CheckPermission(src, 'bulletin_post')
    local isOwner      = existing.created_by == citizenId

    -- Authors can edit their own posts; supervisors can edit any post in the same department
    if not isOwner and not isSupervisor then
        return { success = false, error = 'No permission to edit this post' }
    end
    if existing.job ~= jobName then
        return { success = false, error = 'Post belongs to a different department' }
    end

    local VALID_CATEGORIES = { announcement = true, operations = true, training = true, general = true, warrants = true }
    local VALID_PRIORITIES  = { low = true, normal = true, high = true, urgent = true }

    local sets = {}
    local vals = {}

    if updates.title ~= nil then
        local t = tostring(updates.title):gsub('^%s+', ''):gsub('%s+$', '')
        if t ~= '' then
            sets[#sets + 1] = 'title = ?'
            vals[#vals + 1] = t:sub(1, 255)
        end
    end
    if updates.content ~= nil then
        sets[#sets + 1] = 'content = ?'
        vals[#vals + 1] = tostring(updates.content):sub(1, 65535)
    end
    if updates.category ~= nil and VALID_CATEGORIES[updates.category] then
        sets[#sets + 1] = 'category = ?'
        vals[#vals + 1] = updates.category
    end
    if updates.priority ~= nil and VALID_PRIORITIES[updates.priority] then
        sets[#sets + 1] = 'priority = ?'
        vals[#vals + 1] = updates.priority
    end
    -- Only supervisors may change pin state
    if updates.pinned ~= nil and isSupervisor then
        sets[#sets + 1] = 'pinned = ?'
        vals[#vals + 1] = updates.pinned and 1 or 0
    end

    if #sets == 0 then return { success = false, error = 'No valid fields to update' } end

    vals[#vals + 1] = postId
    MySQL.update.await('UPDATE mdt_bulletin_posts SET ' .. table.concat(sets, ', ') .. ' WHERE id = ?', vals)
    return { success = true }
end)

-- ── Delete a bulletin post (soft delete) ─────────────────────

ps.registerCallback(resourceName .. ':server:deleteBulletinPost', function(source, postId)
    local src = source
    if not CheckAuth(src) then return { success = false, error = 'Unauthorized' } end

    postId = tonumber(postId)
    if not postId then return { success = false, error = 'Invalid post id' } end

    local existing = MySQL.single.await(
        'SELECT created_by, job FROM mdt_bulletin_posts WHERE id = ?',
        { postId }
    )
    if not existing then return { success = false, error = 'Post not found' } end

    local jobName      = ps.getJobName(src)
    local citizenId    = ps.getIdentifier(src)
    local isSupervisor = CheckPermission(src, 'bulletin_pin')
    local isOwner      = existing.created_by == citizenId

    if not isOwner and not isSupervisor then
        return { success = false, error = 'No permission to delete this post' }
    end
    if existing.job ~= jobName then
        return { success = false, error = 'Post belongs to a different department' }
    end

    MySQL.update.await('DELETE FROM mdt_bulletin_posts WHERE id = ?', { postId })
    return { success = true }
end)

-- ── Toggle pin on a bulletin post ────────────────────────────

ps.registerCallback(resourceName .. ':server:toggleBulletinPin', function(source, postId)
    local src = source
    local newPinned = 0
    if not CheckAuth(src) then return { success = false, error = 'Unauthorized' } end
    if not CheckPermission(src, 'bulletin_pin') then
        return { success = false, error = 'No permission to pin posts' }
    end

    postId = tonumber(postId)
    if not postId then return { success = false, error = 'Invalid post id' } end

    local existing = MySQL.single.await(
        'SELECT pinned, job FROM mdt_bulletin_posts WHERE id = ?',
        { postId }
    )
    if not existing then return { success = false, error = 'Post not found' } end

    local jobName = ps.getJobName(src)
    if existing.job ~= jobName then
        return { success = false, error = 'Post belongs to a different department' }
    end

    local isPinned = existing.pinned == 1 or existing.pinned == "1" or existing.pinned == true
    
    if not isPinned then
        newPinned = 1
    end
    
    MySQL.update.await(
        'UPDATE mdt_bulletin_posts SET pinned = ? WHERE id = ?',
        { newPinned, postId }
    )

    return { success = true, pinned = newPinned }
end)