local resourceName = tostring(GetCurrentResourceName())

-- Get all SOP categories with their sections for the officer's department
ps.registerCallback(resourceName .. ':server:getSOPCategories', function(source)
    local src = source
    if not CheckAuth(src) then return {} end

    local jobName = ps.getJobName(src)
    if not jobName or jobName == '' then return {} end

    local ok, categories = pcall(MySQL.query.await, [[
        SELECT id, title, icon, sort_order
        FROM mdt_sop_categories
        WHERE job = ?
        ORDER BY sort_order ASC, id ASC
    ]], { jobName })

    if not ok or not categories then return {} end

    -- Fetch sections for each category
    for _, cat in ipairs(categories) do
        local sOk, sections = pcall(MySQL.query.await, [[
            SELECT id, title, content, sort_order
            FROM mdt_sop_sections
            WHERE category_id = ?
            ORDER BY sort_order ASC, id ASC
        ]], { cat.id })
        cat.sections = (sOk and sections) or {}
    end

    return categories
end)

-- Create a new SOP category
ps.registerCallback(resourceName .. ':server:createSOPCategory', function(source, data)
    local src = source
    if not CheckAuth(src) then return { success = false, error = 'Unauthorized' } end
    if not CheckPermission(src, 'sop_manage') then
        return { success = false, error = 'No permission to manage SOPs' }
    end

    data = data or {}
    local title = data.title or ''
    if title == '' then return { success = false, error = 'Title is required' } end

    local jobName = ps.getJobName(src)

    -- Get next sort order
    local maxRow = MySQL.single.await('SELECT COALESCE(MAX(sort_order), 0) as max_sort FROM mdt_sop_categories WHERE job = ?', { jobName })
    local nextSort = (maxRow and maxRow.max_sort or 0) + 1

    local id = MySQL.insert.await([[
        INSERT INTO mdt_sop_categories (job, title, icon, sort_order)
        VALUES (?, ?, ?, ?)
    ]], { jobName, title, data.icon or 'description', nextSort })

    if not id then return { success = false, error = 'Failed to create category' } end
    return { success = true, id = id }
end)

-- Update a SOP category
ps.registerCallback(resourceName .. ':server:updateSOPCategory', function(source, categoryId, updates)
    local src = source
    if not CheckAuth(src) then return { success = false, error = 'Unauthorized' } end
    if not CheckPermission(src, 'sop_manage') then
        return { success = false, error = 'No permission to manage SOPs' }
    end

    categoryId = tonumber(categoryId)
    updates = updates or {}
    if not categoryId then return { success = false, error = 'Invalid category id' } end

    local sets = {}
    local vals = {}

    local allowedFields = { 'title', 'icon', 'sort_order' }
    for _, field in ipairs(allowedFields) do
        if updates[field] ~= nil then
            sets[#sets + 1] = field .. ' = ?'
            vals[#vals + 1] = updates[field]
        end
    end

    if #sets == 0 then return { success = false, error = 'No fields to update' } end

    vals[#vals + 1] = categoryId
    MySQL.update.await('UPDATE mdt_sop_categories SET ' .. table.concat(sets, ', ') .. ' WHERE id = ?', vals)
    return { success = true }
end)

-- Delete a SOP category (cascades to sections)
ps.registerCallback(resourceName .. ':server:deleteSOPCategory', function(source, categoryId)
    local src = source
    if not CheckAuth(src) then return { success = false, error = 'Unauthorized' } end
    if not CheckPermission(src, 'sop_manage') then
        return { success = false, error = 'No permission to manage SOPs' }
    end

    categoryId = tonumber(categoryId)
    if not categoryId then return { success = false, error = 'Invalid category id' } end

    MySQL.query.await('DELETE FROM mdt_sop_categories WHERE id = ?', { categoryId })
    return { success = true }
end)

-- Create a new SOP section within a category
ps.registerCallback(resourceName .. ':server:createSOPSection', function(source, data)
    local src = source
    if not CheckAuth(src) then return { success = false, error = 'Unauthorized' } end
    if not CheckPermission(src, 'sop_manage') then
        return { success = false, error = 'No permission to manage SOPs' }
    end

    data = data or {}
    local categoryId = tonumber(data.category_id)
    local title = data.title or ''
    if not categoryId or title == '' then
        return { success = false, error = 'Category and title are required' }
    end

    -- Get next sort order within this category
    local maxRow = MySQL.single.await('SELECT COALESCE(MAX(sort_order), 0) as max_sort FROM mdt_sop_sections WHERE category_id = ?', { categoryId })
    local nextSort = (maxRow and maxRow.max_sort or 0) + 1

    local id = MySQL.insert.await([[
        INSERT INTO mdt_sop_sections (category_id, title, content, sort_order)
        VALUES (?, ?, ?, ?)
    ]], { categoryId, title, data.content or '', nextSort })

    if not id then return { success = false, error = 'Failed to create section' } end
    return { success = true, id = id }
end)

-- Update a SOP section
ps.registerCallback(resourceName .. ':server:updateSOPSection', function(source, sectionId, updates)
    local src = source
    if not CheckAuth(src) then return { success = false, error = 'Unauthorized' } end
    if not CheckPermission(src, 'sop_manage') then
        return { success = false, error = 'No permission to manage SOPs' }
    end

    sectionId = tonumber(sectionId)
    updates = updates or {}
    if not sectionId then return { success = false, error = 'Invalid section id' } end

    local sets = {}
    local vals = {}

    local allowedFields = { 'title', 'content', 'sort_order' }
    for _, field in ipairs(allowedFields) do
        if updates[field] ~= nil then
            sets[#sets + 1] = field .. ' = ?'
            vals[#vals + 1] = updates[field]
        end
    end

    if #sets == 0 then return { success = false, error = 'No fields to update' } end

    vals[#vals + 1] = sectionId
    MySQL.update.await('UPDATE mdt_sop_sections SET ' .. table.concat(sets, ', ') .. ' WHERE id = ?', vals)
    return { success = true }
end)

-- Delete a SOP section
ps.registerCallback(resourceName .. ':server:deleteSOPSection', function(source, sectionId)
    local src = source
    if not CheckAuth(src) then return { success = false, error = 'Unauthorized' } end
    if not CheckPermission(src, 'sop_manage') then
        return { success = false, error = 'No permission to manage SOPs' }
    end

    sectionId = tonumber(sectionId)
    if not sectionId then return { success = false, error = 'Invalid section id' } end

    MySQL.query.await('DELETE FROM mdt_sop_sections WHERE id = ?', { sectionId })
    return { success = true }
end)

-- Get SOP settings for the officer's department
ps.registerCallback(resourceName .. ':server:getSOPSettings', function(source)
    local src = source
    if not CheckAuth(src) then return {} end

    local jobName = ps.getJobName(src)
    if not jobName or jobName == '' then return {} end

    local row = MySQL.single.await('SELECT * FROM mdt_sop_settings WHERE job = ?', { jobName })
    return row or { job = jobName, introduction = '', mission_statement = '', version = 0 }
end)

-- Update SOP mission statement
ps.registerCallback(resourceName .. ':server:updateSOPMission', function(source, missionStatement)
    local src = source
    if not CheckAuth(src) then return { success = false, error = 'Unauthorized' } end
    if not CheckPermission(src, 'sop_manage') then
        return { success = false, error = 'No permission to manage SOPs' }
    end

    local jobName = ps.getJobName(src)
    local citizenId = ps.getIdentifier(src)
    local profile = MySQL.single.await('SELECT fullname FROM mdt_profiles WHERE citizenid = ?', { citizenId })
    local updatedBy = profile and profile.fullname or 'Unknown'

    MySQL.query.await([[
        INSERT INTO mdt_sop_settings (job, mission_statement, version, updated_by)
        VALUES (?, ?, 0, ?)
        ON DUPLICATE KEY UPDATE mission_statement = VALUES(mission_statement), updated_by = VALUES(updated_by)
    ]], { jobName, missionStatement or '', updatedBy })

    return { success = true }
end)

-- Update SOP introduction text
ps.registerCallback(resourceName .. ':server:updateSOPIntro', function(source, introduction)
    local src = source
    if not CheckAuth(src) then return { success = false, error = 'Unauthorized' } end
    if not CheckPermission(src, 'sop_manage') then
        return { success = false, error = 'No permission to manage SOPs' }
    end

    local jobName = ps.getJobName(src)
    local citizenId = ps.getIdentifier(src)
    local profile = MySQL.single.await('SELECT fullname FROM mdt_profiles WHERE citizenid = ?', { citizenId })
    local updatedBy = profile and profile.fullname or 'Unknown'

    MySQL.query.await([[
        INSERT INTO mdt_sop_settings (job, introduction, version, updated_by)
        VALUES (?, ?, 0, ?)
        ON DUPLICATE KEY UPDATE introduction = VALUES(introduction), updated_by = VALUES(updated_by)
    ]], { jobName, introduction or '', updatedBy })

    return { success = true }
end)

-- Publish SOP (bump version, forcing all officers to re-acknowledge)
ps.registerCallback(resourceName .. ':server:publishSOP', function(source)
    local src = source
    if not CheckAuth(src) then return { success = false, error = 'Unauthorized' } end
    if not CheckPermission(src, 'sop_manage') then
        return { success = false, error = 'No permission to manage SOPs' }
    end

    local jobName = ps.getJobName(src)
    local citizenId = ps.getIdentifier(src)
    local profile = MySQL.single.await('SELECT fullname FROM mdt_profiles WHERE citizenid = ?', { citizenId })
    local updatedBy = profile and profile.fullname or 'Unknown'

    -- Upsert: create with version 1, or increment existing version
    MySQL.query.await([[
        INSERT INTO mdt_sop_settings (job, introduction, version, updated_by)
        VALUES (?, '', 1, ?)
        ON DUPLICATE KEY UPDATE version = version + 1, updated_by = VALUES(updated_by)
    ]], { jobName, updatedBy })

    local row = MySQL.single.await('SELECT version FROM mdt_sop_settings WHERE job = ?', { jobName })
    return { success = true, version = row and row.version or 1 }
end)

-- Check if the officer has agreed to the current SOP version
ps.registerCallback(resourceName .. ':server:checkSOPAgreement', function(source)
    local src = source
    if not CheckAuth(src) then return { agreed = true } end

    local jobName = ps.getJobName(src)
    local citizenId = ps.getIdentifier(src)

    -- Get current SOP version for this department
    local settings = MySQL.single.await('SELECT version, introduction, mission_statement FROM mdt_sop_settings WHERE job = ?', { jobName })

    -- No SOP published yet — skip agreement
    if not settings or not settings.version or settings.version == 0 then
        return { agreed = true, introduction = '' }
    end

    -- Check if officer has agreed to this version
    local ack = MySQL.single.await([[
        SELECT version FROM mdt_sop_acknowledgements
        WHERE citizenid = ? AND job = ?
    ]], { citizenId, jobName })

    local agreed = ack and ack.version and ack.version >= settings.version or false

    return {
        agreed = agreed,
        introduction = settings.introduction or '',
        mission_statement = settings.mission_statement or '',
        currentVersion = settings.version
    }
end)

-- Record SOP acknowledgement
ps.registerCallback(resourceName .. ':server:acknowledgesSOP', function(source)
    local src = source
    if not CheckAuth(src) then return { success = false } end

    local jobName = ps.getJobName(src)
    local citizenId = ps.getIdentifier(src)

    -- Get current version
    local settings = MySQL.single.await('SELECT version FROM mdt_sop_settings WHERE job = ?', { jobName })
    if not settings or not settings.version then
        return { success = false, error = 'No SOP published' }
    end

    MySQL.query.await([[
        INSERT INTO mdt_sop_acknowledgements (citizenid, job, version)
        VALUES (?, ?, ?)
        ON DUPLICATE KEY UPDATE version = VALUES(version), agreed_at = CURRENT_TIMESTAMP
    ]], { citizenId, jobName, settings.version })

    return { success = true }
end)
