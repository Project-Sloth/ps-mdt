local resourceName = tostring(GetCurrentResourceName())

-- Action-to-category mapping
local ACTION_CATEGORIES = {
    mdt_login = 'authentication',
    mdt_logout = 'authentication',
    report_created = 'reports',
    report_updated = 'reports',
    report_deleted = 'reports',
    case_created = 'cases',
    case_updated = 'cases',
    case_deleted = 'cases',
    case_officer_assigned = 'cases',
    case_officer_removed = 'cases',
    case_attachment_added = 'cases',
    case_attachment_uploaded = 'cases',
    case_attachment_removed = 'cases',
    evidence_added = 'evidence',
    evidence_updated = 'evidence',
    evidence_deleted = 'evidence',
    evidence_transferred = 'evidence',
    evidence_image_added = 'evidence',
    evidence_image_removed = 'evidence',
    evidence_linked_case = 'evidence',
    case_created_from_evidence = 'evidence',
    warrant_issued = 'warrants',
    warrant_closed = 'warrants',
    vehicle_updated = 'vehicles',
    vehicle_impounded = 'vehicles',
    vehicle_released = 'vehicles',
    weapon_created = 'weapons',
    weapon_updated = 'weapons',
    weapon_deleted = 'weapons',
    fine_processed = 'charges',
    charge_updated = 'charges',
    search_citizens = 'searches',
    search_players = 'searches',
    search_officers = 'searches',
    signal100_activated = 'dispatch',
    signal100_deactivated = 'dispatch',
    callsign_changed = 'officers',
    sent_to_jail = 'sentencing',
    arrest_logged = 'arrests',
    icu_deleted = 'icu',
    camera_viewed = 'cameras',
    bodycam_viewed = 'bodycams',
}

-- Cache for tracking config (loaded once, updated on save)
local trackingConfig = nil

local function getDefaultTracking()
    return Config and Config.AuditTracking or {
        authentication = true,
        reports = true,
        cases = true,
        evidence = true,
        warrants = true,
        vehicles = true,
        weapons = true,
        charges = true,
        searches = false,
        dispatch = true,
        officers = true,
        sentencing = true,
        arrests = true,
        icu = true,
        cameras = true,
        bodycams = true,
    }
end

local function loadTrackingConfig()
    local row = MySQL.single.await('SELECT `value` FROM mdt_settings WHERE `key` = ?', { 'audit_tracking' })
    if row and row.value then
        local ok, decoded = pcall(json.decode, row.value)
        if ok and type(decoded) == 'table' then
            -- Merge with defaults so new categories get their default value
            local defaults = getDefaultTracking()
            for k, v in pairs(defaults) do
                if decoded[k] == nil then
                    decoded[k] = v
                end
            end
            trackingConfig = decoded
            return trackingConfig
        end
    end
    trackingConfig = getDefaultTracking()
    return trackingConfig
end

function GetTrackingConfig()
    if trackingConfig then return trackingConfig end
    return loadTrackingConfig()
end

function IsActionTracked(action)
    local config = GetTrackingConfig()
    local category = ACTION_CATEGORIES[action]
    if not category then return true end -- unknown actions are always tracked
    if config[category] == nil then return true end
    return config[category] == true
end

-- Expose for audit.lua
ps.isActionTracked = IsActionTracked
ps.actionCategories = ACTION_CATEGORIES

-- Get tracking config callback
ps.registerCallback(resourceName .. ':server:getAuditTrackingConfig', function(source)
    local src = source
    if not CheckAuth(src) then return '{}' end
    -- Return as JSON string to preserve boolean false values through msgpack
    return json.encode(GetTrackingConfig())
end)

-- Save tracking config callback
ps.registerCallback(resourceName .. ':server:saveAuditTrackingConfig', function(source, payload)
    local src = source
    if not CheckAuth(src) then return { success = false, message = 'Unauthorized' } end

    -- Payload arrives as JSON string to preserve boolean false values through msgpack
    if type(payload) == 'string' then
        local ok, decoded = pcall(json.decode, payload)
        if ok and type(decoded) == 'table' then
            payload = decoded
        else
            return { success = false, message = 'Invalid payload' }
        end
    end

    if type(payload) ~= 'table' then
        return { success = false, message = 'Invalid payload' }
    end

    -- Validate: only allow known category keys with boolean values
    local defaults = getDefaultTracking()
    local sanitized = {}
    for k, _ in pairs(defaults) do
        if payload[k] ~= nil then
            sanitized[k] = payload[k] == true
        else
            sanitized[k] = defaults[k]
        end
    end

    MySQL.update.await([[
        INSERT INTO mdt_settings (`key`, `value`)
        VALUES (?, ?)
        ON DUPLICATE KEY UPDATE `value` = VALUES(`value`)
    ]], { 'audit_tracking', json.encode(sanitized) })

    trackingConfig = sanitized

    ps.auditLog(src, 'settings_updated', 'settings', 'audit_tracking', sanitized)

    return { success = true }
end)

-- Jail / Fines Configuration

local jailFinesConfig = nil

local function getDefaultJailFinesConfig()
    return {
        reductionOffers = { 10, 25, 50 },  -- % options shown on the Reduction button
        maxFineAmount = (Config and Config.Fines and Config.Fines.MaxAmount) or 100000,
    }
end

local function loadJailFinesConfig()
    local row = MySQL.single.await('SELECT `value` FROM mdt_settings WHERE `key` = ?', { 'jail_fines' })
    if row and row.value then
        local ok, decoded = pcall(json.decode, row.value)
        if ok and type(decoded) == 'table' then
            local defaults = getDefaultJailFinesConfig()
            if not decoded.reductionOffers or type(decoded.reductionOffers) ~= 'table' or #decoded.reductionOffers == 0 then
                decoded.reductionOffers = defaults.reductionOffers
            end
            if not decoded.maxFineAmount or tonumber(decoded.maxFineAmount) == nil then
                decoded.maxFineAmount = defaults.maxFineAmount
            end
            jailFinesConfig = decoded
            return jailFinesConfig
        end
    end
    jailFinesConfig = getDefaultJailFinesConfig()
    return jailFinesConfig
end

function GetJailFinesConfig()
    if jailFinesConfig then return jailFinesConfig end
    return loadJailFinesConfig()
end

ps.registerCallback(resourceName .. ':server:getJailFinesConfig', function(source)
    local src = source
    if not CheckAuth(src) then return {} end
    return GetJailFinesConfig()
end)

ps.registerCallback(resourceName .. ':server:saveJailFinesConfig', function(source, payload)
    local src = source
    if not CheckAuth(src) then return { success = false, message = 'Unauthorized' } end
    if not CheckPermission(src, 'management_settings') then
        return { success = false, message = 'You do not have permission to change these settings' }
    end

    if type(payload) ~= 'table' then
        return { success = false, message = 'Invalid payload' }
    end

    -- Validate reductionOffers: must be array of numbers 1-100
    local offers = {}
    if type(payload.reductionOffers) == 'table' then
        for _, v in ipairs(payload.reductionOffers) do
            local num = tonumber(v)
            if num and num >= 1 and num <= 100 then
                offers[#offers + 1] = math.floor(num)
            end
        end
    end
    if #offers == 0 then
        offers = getDefaultJailFinesConfig().reductionOffers
    end

    local maxFine = tonumber(payload.maxFineAmount)
    if not maxFine or maxFine < 0 then
        maxFine = getDefaultJailFinesConfig().maxFineAmount
    end
    maxFine = math.floor(maxFine)

    local sanitized = {
        reductionOffers = offers,
        maxFineAmount = maxFine,
    }

    MySQL.update.await([[
        INSERT INTO mdt_settings (`key`, `value`)
        VALUES (?, ?)
        ON DUPLICATE KEY UPDATE `value` = VALUES(`value`)
    ]], { 'jail_fines', json.encode(sanitized) })

    jailFinesConfig = sanitized

    if ps.auditLog then
        ps.auditLog(src, 'settings_updated', 'settings', 'jail_fines', sanitized)
    end

    return { success = true }
end)

-- Report Templates Configuration

ps.registerCallback(resourceName .. ':server:getReportTemplates', function(source, data)
    local src = source
    if not CheckAuth(src) then return {} end

    local jobType = (type(data) == 'table' and data.jobType) or 'all'
    -- Return templates matching the job type or 'all'
    local rows = MySQL.query.await(
        'SELECT `id`, `name`, `type`, `content`, `job_type` FROM mdt_report_templates WHERE `job_type` = ? OR `job_type` = ? ORDER BY `type`, `name`',
        { jobType, 'all' }
    )
    return rows or {}
end)

ps.registerCallback(resourceName .. ':server:saveReportTemplate', function(source, payload)
    local src = source
    if not CheckAuth(src) then return { success = false, message = 'Unauthorized' } end
    if not CheckPermission(src, 'management_settings') then
        return { success = false, message = 'You do not have permission to change templates' }
    end

    if type(payload) ~= 'table' then
        return { success = false, message = 'Invalid payload' }
    end

    local name = tostring(payload.name or ''):sub(1, 100)
    local tmplType = tostring(payload.type or ''):sub(1, 50)
    local content = tostring(payload.content or '')

    if name == '' or tmplType == '' or content == '' then
        return { success = false, message = 'Name, type, and content are required' }
    end

    local jobType = tostring(payload.jobType or 'all'):sub(1, 10)
    -- Validate job_type
    if jobType ~= 'leo' and jobType ~= 'ems' and jobType ~= 'all' then
        jobType = 'all'
    end

    local templateId = payload.id and tonumber(payload.id) or nil

    if templateId then
        -- Update existing
        MySQL.update.await('UPDATE mdt_report_templates SET `name` = ?, `type` = ?, `content` = ?, `job_type` = ? WHERE `id` = ?', {
            name, tmplType, content, jobType, templateId
        })
    else
        -- Insert new
        templateId = MySQL.insert.await('INSERT INTO mdt_report_templates (`name`, `type`, `content`, `job_type`) VALUES (?, ?, ?, ?)', {
            name, tmplType, content, jobType
        })
    end

    if ps.auditLog then
        ps.auditLog(src, 'settings_updated', 'settings', 'report_template_' .. tostring(templateId), { name = name, type = tmplType, jobType = jobType })
    end

    return { success = true, template = { id = templateId, name = name, type = tmplType, content = content, job_type = jobType } }
end)

ps.registerCallback(resourceName .. ':server:deleteReportTemplate', function(source, payload)
    local src = source
    if not CheckAuth(src) then return { success = false, message = 'Unauthorized' } end
    if not CheckPermission(src, 'management_settings') then
        return { success = false, message = 'You do not have permission to delete templates' }
    end

    if type(payload) ~= 'table' or not payload.id then
        return { success = false, message = 'Invalid payload' }
    end

    local id = tonumber(payload.id)
    if not id then
        return { success = false, message = 'Invalid template ID' }
    end

    MySQL.update.await('DELETE FROM mdt_report_templates WHERE `id` = ?', { id })

    if ps.auditLog then
        ps.auditLog(src, 'settings_updated', 'settings', 'report_template_' .. tostring(id), { action = 'deleted' })
    end

    return { success = true }
end)

-- ═══════════════════════════════════════════════════════════════
--  COLORS CONFIG
-- ═══════════════════════════════════════════════════════════════

local colorConfigCache = nil

local function getColorSettingsKey(src)
    local jobName = ps.getJobName and ps.getJobName(src) or 'police'
    return 'colors_' .. (jobName or 'police')
end

ps.registerCallback(resourceName .. ':server:getColorConfig', function(source)
    local src = source
    if not CheckAuth(src) then return nil end

    local settingsKey = getColorSettingsKey(src)

    if colorConfigCache and colorConfigCache._key == settingsKey then
        return colorConfigCache
    end

    local rows = MySQL.query.await('SELECT `value` FROM mdt_settings WHERE `key` = ?', { settingsKey })
    if rows and rows[1] and rows[1].value then
        local ok, parsed = pcall(json.decode, rows[1].value)
        if ok and parsed then
            parsed._key = settingsKey
            colorConfigCache = parsed
            return parsed
        end
    end

    return nil
end)

ps.registerCallback(resourceName .. ':server:saveColorConfig', function(source, payload)
    local src = source
    if not CheckAuth(src) then return { success = false, message = 'Unauthorized' } end
    if not CheckPermission(src, 'management_settings') then
        return { success = false, message = 'You do not have permission to change color settings' }
    end

    if type(payload) ~= 'table' then
        return { success = false, message = 'Invalid payload' }
    end

    local config = {
        accent = type(payload.accent) == 'string' and payload.accent or nil,
        accentText = type(payload.accentText) == 'string' and payload.accentText or nil,
        background = type(payload.background) == 'string' and payload.background or nil,
        cardBackground = type(payload.cardBackground) == 'string' and payload.cardBackground or nil,
        buttonPrimary = type(payload.buttonPrimary) == 'string' and payload.buttonPrimary or nil,
    }

    if not config.accent then
        return { success = false, message = 'Accent color is required' }
    end

    local settingsKey = getColorSettingsKey(src)
    local jsonValue = json.encode(config)

    MySQL.query.await([[
        INSERT INTO mdt_settings (`key`, `value`) VALUES (?, ?)
        ON DUPLICATE KEY UPDATE `value` = VALUES(`value`)
    ]], { settingsKey, jsonValue })

    config._key = settingsKey
    colorConfigCache = config

    if ps.auditLog then
        ps.auditLog(src, 'settings_updated', 'settings', settingsKey, config)
    end

    return { success = true }
end)
