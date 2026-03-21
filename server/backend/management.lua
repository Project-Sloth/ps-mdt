local resourceName = tostring(GetCurrentResourceName())

local function resolvePoliceJobName(source)
    local jobName = (Config and Config.PoliceJobs and Config.PoliceJobs[1]) or 'police'
    if source and ps and ps.getJobName then
        local playerJob = ps.getJobName(source)
        if playerJob then
            jobName = playerJob
        end
    end
    return jobName
end

local function normalizeGrades(grades)
    local result = {}
    for key, data in pairs(grades or {}) do
        local gradeKey = key
        if type(data) == 'table' then
            gradeKey = data.level or data.grade or data.rank or data.value or data.id or key
        end
        result[tostring(gradeKey)] = data
    end
    return result
end

local function isBossGrade(gradeData)
    return gradeData and (gradeData.isboss == true or gradeData.isBoss == true or gradeData.boss == true)
end

local function getGradeLabel(gradeData, gradeKeyString)
    if gradeData then
        return gradeData.name or gradeData.label or gradeData.title or ('Grade ' .. gradeKeyString)
    end
    return 'Grade ' .. gradeKeyString
end

local function getPoliceJobDefinition(source)
    local jobName = resolvePoliceJobName(source)

    if exports['qb-core'] then
        local QBCore = exports['qb-core']:GetCoreObject()
        local jobs = QBCore and QBCore.Shared and QBCore.Shared.Jobs
        if jobs and jobs[jobName] then
            return jobName, jobs[jobName]
        end
    end

    if ps and ps.getSharedJobData then
        local job = ps.getSharedJobData(jobName)
        if job then
            return jobName, job
        end
    end

    return jobName, nil
end

local function getAllPermissions()
    return (Config and Config.ManagementPermissions) or {
        'citizens_search', 'citizens_edit_licenses',
        'bolos_view', 'bolos_create',
        'vehicles_search', 'vehicles_edit_dmv',
        'weapons_search',
        'cases_view', 'cases_create', 'cases_edit', 'cases_delete',
        'evidence_view', 'evidence_create', 'evidence_transfer', 'evidence_upload',
        'reports_view', 'reports_create', 'reports_delete',
        'warrants_view', 'warrants_issue', 'warrants_close',
        'charges_view', 'charges_edit',
        'dispatch_attach', 'dispatch_route',
        'cameras_view', 'bodycams_view',
        'notes_edit_department',
        'roster_manage_certifications',
        'management_permissions', 'management_bulletins', 'management_activity',
        'management_tags', 'management_tracking',
    }
end

local function normalizePermissionList(list)
    local result = {}
    local seen = {}
    for _, perm in ipairs(list or {}) do
        if perm and not seen[perm] then
            seen[perm] = true
            result[#result + 1] = perm
        end
    end
    table.sort(result)
    return result
end

local function getDefaultRolePermissions(jobName, gradeKey, isBoss)
    if isBoss then
        return normalizePermissionList(getAllPermissions())
    end

    local defaults = Config and Config.PermissionDefaults and Config.PermissionDefaults[jobName]
    if defaults and defaults[tostring(gradeKey)] then
        return normalizePermissionList(defaults[tostring(gradeKey)])
    end

    return {}
end

ps.registerCallback(resourceName .. ':server:getPermissionRoles', function(source)
    local src = source
    if not CheckAuth(src) then return {} end

    local jobName, job = getPoliceJobDefinition(src)
    local hasBossAccess = false
    if ps and ps.getJobData then
        local jobData = ps.getJobData(src)
        if jobData and jobData.grade then
            if type(jobData.grade) == 'table' then
                hasBossAccess = jobData.grade.isboss == true or jobData.grade.isBoss == true or jobData.grade.boss == true
            else
                local grades = job and job.grades and normalizeGrades(job.grades) or nil
                if grades then
                    local gradeData = grades[tostring(jobData.grade)]
                    hasBossAccess = isBossGrade(gradeData)
                end
            end
        end
    end
    ps.debug('[getPermissionRoles] jobName', jobName, 'job', job and job.label or 'nil')
    if not job or not job.grades then
        ps.debug('[getPermissionRoles] no job grades, using fallback')
        local isBoss = ps and ps.isBoss and ps.isBoss(src) or false
        local fallbackPermissions = getDefaultRolePermissions(jobName, 0, isBoss)
        return {
            job = jobName,
            label = 'Law Enforcement',
            roles = {
                {
                    key = '0',
                    label = 'Officer',
                    isBoss = isBoss,
                    permissions = fallbackPermissions,
                }
            },
            permissions = getAllPermissions(),
        }
    end

    local roles = {}
    local storedRows = MySQL.query.await('SELECT grade, permissions FROM mdt_permission_roles WHERE job = ?', { jobName }) or {}
    ps.debug('[getPermissionRoles] stored rows', storedRows and #storedRows or 0)
    local storedByGrade = {}
    for _, row in ipairs(storedRows) do
        if row.grade ~= nil then
            local ok, decoded = pcall(json.decode, row.permissions)
            storedByGrade[tostring(row.grade)] = ok and decoded or {}
        end
    end

    local grades = normalizeGrades(job.grades)
    local gradeCount = 0
    for _ in pairs(grades or {}) do
        gradeCount = gradeCount + 1
    end
    ps.debug('[getPermissionRoles] grade count', gradeCount)
    for gradeKeyString, gradeData in pairs(grades) do
        local isBoss = hasBossAccess or isBossGrade(gradeData)
        local permissions = storedByGrade[gradeKeyString]
        if not permissions or #permissions == 0 then
            permissions = getDefaultRolePermissions(jobName, gradeKeyString, isBoss)
        end
        permissions = normalizePermissionList(permissions)

        roles[#roles + 1] = {
            key = gradeKeyString,
            label = getGradeLabel(gradeData, gradeKeyString),
            isBoss = isBoss,
            permissions = permissions,
        }
    end

    if #roles == 0 and ps and ps.getJobData then
        local jobData = ps.getJobData(src)
        if jobData then
            local gradeValue = jobData.grade
            local gradeLabel = nil
            local isBoss = false
            if type(gradeValue) == 'table' then
                gradeLabel = gradeValue.name or gradeValue.label
                isBoss = gradeValue.isboss == true or gradeValue.isBoss == true or gradeValue.boss == true
                gradeValue = gradeValue.level or gradeValue.grade or gradeValue.rank or gradeValue.value or gradeValue.id
            end
            gradeValue = gradeValue or 0
            local gradeKeyString = tostring(gradeValue)
            local permissions = storedByGrade[gradeKeyString]
            if not permissions or #permissions == 0 then
                permissions = getDefaultRolePermissions(jobName, gradeKeyString, isBoss)
            end
            permissions = normalizePermissionList(permissions)
            roles[#roles + 1] = {
                key = gradeKeyString,
                label = gradeLabel or ('Grade ' .. gradeKeyString),
                isBoss = isBoss,
                permissions = permissions,
            }
        end
    end

    table.sort(roles, function(a, b)
        local numA = tonumber(a.key)
        local numB = tonumber(b.key)
        if numA and numB then return numA < numB end
        if numA then return true end
        if numB then return false end
        return (a.key or '') < (b.key or '')
    end)

    return {
        job = jobName,
        label = job.label or 'Law Enforcement',
        roles = roles,
        permissions = getAllPermissions(),
    }
end)

ps.registerCallback(resourceName .. ':server:updatePermissionRole', function(source, payload)
    local src = source
    if not CheckAuth(src) then return { success = false, message = 'Unauthorized' } end

    payload = payload or {}
    if not payload.job or payload.grade == nil or type(payload.permissions) ~= 'table' then
        return { success = false, message = 'Invalid payload' }
    end

    local jobName, job = getPoliceJobDefinition(src)
    local isBoss = false
    if job and job.grades then
        local grades = normalizeGrades(job.grades)
        local gradeData = grades[tostring(payload.grade)]
        if gradeData then
            isBoss = isBossGrade(gradeData)
        end
    end

    local permissions = normalizePermissionList(payload.permissions)
    if isBoss then
        permissions = normalizePermissionList(getAllPermissions())
    end

    local updatedBy = ps.getIdentifier(src)
    MySQL.update.await([[
        INSERT INTO mdt_permission_roles (job, grade, permissions, updated_by)
        VALUES (?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE permissions = VALUES(permissions), updated_by = VALUES(updated_by)
    ]], { payload.job, tonumber(payload.grade), json.encode(permissions), updatedBy })

    return { success = true }
end)

-- TAG MANAGEMENT

-- Ensure mdt_tags table exists
CreateThread(function()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `mdt_tags` (
            `id` INT(10) UNSIGNED NOT NULL AUTO_INCREMENT,
            `name` VARCHAR(25) NOT NULL,
            `type` ENUM('officer','report','both') NOT NULL DEFAULT 'officer',
            `color` VARCHAR(7) NOT NULL DEFAULT '#6b7280',
            `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`),
            UNIQUE KEY `unique_tag_name` (`name`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
    ]])

    -- Fix ENUM if table was created with old 'citizen' value
    pcall(MySQL.query.await, [[
        ALTER TABLE `mdt_tags` MODIFY COLUMN `type` ENUM('officer','report','both') NOT NULL DEFAULT 'officer'
    ]])
    -- Migrate any old 'citizen' rows to 'officer'
    pcall(MySQL.query.await, [[UPDATE `mdt_tags` SET `type` = 'officer' WHERE `type` = 'citizen']])

    -- Seed default tags if table is empty
    local count = MySQL.scalar.await('SELECT COUNT(*) FROM mdt_tags')
    if (tonumber(count) or 0) == 0 then
        -- Default officer tags
        local officerDefaults = {
            { name = 'SWAT',          color = '#3b82f6' },
            { name = 'FTO',           color = '#10b981' },
            { name = 'Detective',     color = '#8b5cf6' },
            { name = 'Probation',     color = '#f59e0b' },
            { name = 'Command',       color = '#ef4444' },
            { name = 'K9 Certified',  color = '#06b6d4' },
            { name = 'Air Certified', color = '#ec4899' },
        }
        for _, tag in ipairs(officerDefaults) do
            pcall(MySQL.insert.await, 'INSERT IGNORE INTO mdt_tags (name, type, color) VALUES (?, ?, ?)', { tag.name, 'officer', tag.color })
        end

        -- Default report tags
        local reportDefaults = {
            { name = 'Robbery',            color = '#ef4444' },
            { name = 'Armed',              color = '#f97316' },
            { name = 'Priority',           color = '#f59e0b' },
            { name = 'Active',             color = '#10b981' },
            { name = 'Ballistics',         color = '#8b5cf6' },
            { name = 'Gang Related',       color = '#ec4899' },
            { name = 'Drug Related',       color = '#06b6d4' },
            { name = 'Traffic',            color = '#3b82f6' },
            { name = 'Domestic',           color = '#6b7280' },
            { name = 'Assault',            color = '#ef4444' },
            { name = 'High Priority',      color = '#f59e0b' },
            { name = 'Confidential',       color = '#8b5cf6' },
            { name = 'Active Investigation', color = '#10b981' },
        }
        for _, tag in ipairs(reportDefaults) do
            pcall(MySQL.insert.await, 'INSERT IGNORE INTO mdt_tags (name, type, color) VALUES (?, ?, ?)', { tag.name, 'report', tag.color })
        end

        -- Also import any existing tags from usage tables
        local existing = MySQL.query.await('SELECT DISTINCT tag FROM mdt_profiles_tags')
        for _, row in ipairs(existing or {}) do
            pcall(MySQL.insert.await, 'INSERT IGNORE INTO mdt_tags (name, type) VALUES (?, ?)', { row.tag, 'officer' })
        end
        local existingReport = MySQL.query.await('SELECT DISTINCT tag FROM mdt_reports_tags')
        for _, row in ipairs(existingReport or {}) do
            pcall(MySQL.insert.await, 'INSERT IGNORE INTO mdt_tags (name, type) VALUES (?, ?)', { row.tag, 'report' })
        end
    end
end)

ps.registerCallback(resourceName .. ':server:getTags', function(source)
    local src = source
    if not CheckAuth(src) then return {} end

    local rows = MySQL.query.await([[
        SELECT t.id, t.name, t.type, t.color, t.created_at,
               (SELECT COUNT(*) FROM mdt_profiles_tags pt WHERE pt.tag = t.name) +
               (SELECT COUNT(*) FROM mdt_reports_tags rt WHERE rt.tag = t.name) AS usage_count
        FROM mdt_tags t
        ORDER BY t.name ASC
    ]])
    return rows or {}
end)

ps.registerCallback(resourceName .. ':server:createTag', function(source, payload)
    local src = source
    if not CheckAuth(src) then return { success = false, message = 'Unauthorized' } end

    payload = payload or {}
    local name = payload.name
    local tagType = payload.type or 'citizen'
    local color = payload.color or '#6b7280'

    if not name or name == '' then
        return { success = false, message = 'Tag name is required' }
    end
    if #name > 25 then
        return { success = false, message = 'Tag name must be 25 characters or less' }
    end

    -- Check duplicate
    local existing = MySQL.scalar.await('SELECT id FROM mdt_tags WHERE name = ?', { name })
    if existing then
        return { success = false, message = 'Tag already exists' }
    end

    local id = MySQL.insert.await('INSERT INTO mdt_tags (name, type, color) VALUES (?, ?, ?)', { name, tagType, color })
    if not id then
        return { success = false, message = 'Failed to create tag' }
    end

    return { success = true, id = id }
end)

ps.registerCallback(resourceName .. ':server:updateTag', function(source, payload)
    local src = source
    if not CheckAuth(src) then return { success = false, message = 'Unauthorized' } end

    payload = payload or {}
    local id = tonumber(payload.id)
    local name = payload.name
    local tagType = payload.type
    local color = payload.color

    if not id then
        return { success = false, message = 'Invalid tag ID' }
    end
    if not name or name == '' then
        return { success = false, message = 'Tag name is required' }
    end
    if #name > 25 then
        return { success = false, message = 'Tag name must be 25 characters or less' }
    end

    -- Get old name to update references
    local oldRow = MySQL.query.await('SELECT name FROM mdt_tags WHERE id = ?', { id })
    local oldName = oldRow and oldRow[1] and oldRow[1].name

    -- Check duplicate (excluding self)
    local dup = MySQL.scalar.await('SELECT id FROM mdt_tags WHERE name = ? AND id != ?', { name, id })
    if dup then
        return { success = false, message = 'Another tag with that name already exists' }
    end

    MySQL.update.await('UPDATE mdt_tags SET name = ?, type = ?, color = ? WHERE id = ?', { name, tagType, color, id })

    -- Update references in profile tags and report tags if name changed
    if oldName and oldName ~= name then
        pcall(MySQL.update.await, 'UPDATE mdt_profiles_tags SET tag = ? WHERE tag = ?', { name, oldName })
        pcall(MySQL.update.await, 'UPDATE mdt_reports_tags SET tag = ? WHERE tag = ?', { name, oldName })
    end

    return { success = true }
end)

ps.registerCallback(resourceName .. ':server:deleteTag', function(source, payload)
    local src = source
    if not CheckAuth(src) then return { success = false, message = 'Unauthorized' } end

    payload = payload or {}
    local id = tonumber(payload.id)
    if not id then
        return { success = false, message = 'Invalid tag ID' }
    end

    -- Get name before deleting so we can clean up references
    local row = MySQL.query.await('SELECT name FROM mdt_tags WHERE id = ?', { id })
    local tagName = row and row[1] and row[1].name

    MySQL.query.await('DELETE FROM mdt_tags WHERE id = ?', { id })

    -- Optionally clean up references (remove tag from all profiles/reports)
    if tagName then
        pcall(MySQL.query.await, 'DELETE FROM mdt_profiles_tags WHERE tag = ?', { tagName })
        pcall(MySQL.query.await, 'DELETE FROM mdt_reports_tags WHERE tag = ?', { tagName })
    end

    return { success = true }
end)
