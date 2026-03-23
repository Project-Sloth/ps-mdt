-- FiveManage API integration for image uploads and activity logging
-- Docs: https://docs.fivemanage.com
--
-- Server.cfg convars:
--   set ps_mdt_fivemanage_key_images "YOUR_IMAGES_API_KEY"
--   set ps_mdt_fivemanage_key_logs   "YOUR_LOGS_API_KEY"

local FiveManageApiUrl = 'https://api.fivemanage.com/api/v3/file/base64'
local FiveManageLogsUrl = 'https://api.fivemanage.com/api/v3/logs'

local FiveManageApiKey = GetConvar('ps_mdt_fivemanage_key_images', '')
local FiveManageLogsKey = GetConvar('ps_mdt_fivemanage_key_logs', '')

local resourceName = tostring(GetCurrentResourceName())

--- Upload a base64 data URI to FiveManage and return the public URL.
--- @param base64Data string     The base64 string (with or without data URI prefix)
--- @param filename string       Original filename for metadata
--- @return string|nil url       The public URL on success, nil on failure
--- @return string|nil error     Error message on failure
function FiveManageUpload(base64Data, filename)
    if not FiveManageApiKey or FiveManageApiKey == '' then
        local msg = 'FiveManage API key not configured. Add to server.cfg: set ps_mdt_fivemanage_key_images "YOUR_KEY"'
        ps.warn(msg)
        return nil, msg
    end

    -- Strip data URI prefix if present (e.g. "data:image/png;base64,")
    local rawBase64 = base64Data
    if type(rawBase64) == 'string' and rawBase64:find('base64,', 1, true) then
        rawBase64 = rawBase64:match('base64,(.+)')
    end

    if not rawBase64 or rawBase64 == '' then
        local msg = 'Empty image data received'
        ps.warn('FiveManage upload: ' .. msg)
        return nil, msg
    end

    local p = promise.new()

    PerformHttpRequest(FiveManageApiUrl, function(statusCode, responseText)
        if statusCode >= 200 and statusCode < 300 and responseText then
            local ok, data = pcall(json.decode, responseText)
            if ok and data and data.data and data.data.url then
                p:resolve({ url = data.data.url })
            elseif ok and data and data.url then
                p:resolve({ url = data.url })
            else
                ps.warn('FiveManage upload: unexpected response: ' .. tostring(responseText))
                p:resolve({ url = nil, error = 'Unexpected API response' })
            end
        else
            local errMsg = 'HTTP ' .. tostring(statusCode)
            if statusCode == 401 or statusCode == 403 then
                errMsg = 'Invalid API key (HTTP ' .. tostring(statusCode) .. ')'
            elseif statusCode == 413 then
                errMsg = 'Image too large for API (HTTP 413)'
            elseif statusCode == 0 or not statusCode then
                errMsg = 'Could not connect to FiveManage API'
            end
            ps.warn('FiveManage upload failed: ' .. errMsg)
            p:resolve({ url = nil, error = errMsg })
        end
    end, 'POST', json.encode({
        base64 = rawBase64,
        filename = filename or 'upload.png',
    }), {
        ['Content-Type'] = 'application/json',
        ['Authorization'] = FiveManageApiKey,
    })

    local result = Citizen.Await(p)
    return result.url, result.error
end


-- Server callback to upload a mugshot from base64 data (API key stays server-side)
ps.registerCallback(resourceName .. ':server:uploadMugshotBase64', function(source, base64Data)
    if not CheckAuth(source) then return { url = nil, error = 'Unauthorized' } end
    if not base64Data or base64Data == '' then
        return { url = nil, error = 'No image data' }
    end
    local url, err = FiveManageUpload(base64Data, 'mugshot_' .. source .. '.png')
    return { url = url, error = err }
end)

-- Server event: receive mugshot URLs from client and store in profile gallery
RegisterNetEvent(resourceName .. ':server:mugshotUpload')
AddEventHandler(resourceName .. ':server:mugshotUpload', function(citizenid, mugshotUrls)
    local src = source
    if not CheckAuth(src) then return end
    if not citizenid or not mugshotUrls or #mugshotUrls == 0 then return end

    -- Ensure profile exists
    if not EnsureProfileExists(citizenid) then
        ps.warn('Failed to create profile for mugshot upload: ' .. citizenid)
        return
    end

    local profile = MySQL.single.await('SELECT id FROM mdt_profiles WHERE citizenid = ?', { citizenid })
    if not profile then
        ps.warn('Profile not found after ensure for mugshot upload: ' .. citizenid)
        return
    end

    -- Set the first mugshot as profile picture
    if mugshotUrls[1] and mugshotUrls[1] ~= '' then
        MySQL.update.await('UPDATE mdt_profiles SET profilepicture = ? WHERE citizenid = ?', { mugshotUrls[1], citizenid })
    end

    -- Add all mugshots to gallery
    for _, url in ipairs(mugshotUrls) do
        if url and url ~= '' and url ~= 'invalid_url' then
            MySQL.insert.await('INSERT INTO mdt_profiles_gallery (profileId, image, label) VALUES (?, ?, ?)', {
                profile.id, url, 'Mugshot'
            })
        end
    end

    ps.debug('Mugshot upload complete for ' .. citizenid .. ' (' .. #mugshotUrls .. ' photos)')
end)

-- Trigger mugshot on a suspect by citizenid (from MDT UI)
ps.registerCallback(resourceName .. ':server:triggerSuspectMugshot', function(source, citizenid)
    if not citizenid then return { success = false, message = 'Missing citizen id' } end

    local targetPlayer = ps.getPlayerByIdentifier(citizenid)
    if not targetPlayer then
        return { success = false, message = 'Suspect is not online' }
    end

    local targetSource = targetPlayer.source or (targetPlayer.PlayerData and targetPlayer.PlayerData.source)
    if not targetSource then
        return { success = false, message = 'Could not find suspect source' }
    end

    TriggerClientEvent(resourceName .. ':client:triggerMugshot', targetSource)
    return { success = true, message = 'Mugshot triggered on suspect' }
end)

-- Upload a profile photo for a suspect via base64 (from MDT UI)
ps.registerCallback(resourceName .. ':server:uploadSuspectPhoto', function(source, citizenid, base64Image)
    if not citizenid or not base64Image then
        return { success = false, message = 'Missing data' }
    end

    local imageUrl, uploadError = FiveManageUpload(base64Image, 'suspect_' .. citizenid .. '.png')
    if not imageUrl then
        return { success = false, message = 'Upload failed: ' .. (uploadError or 'Unknown error') }
    end

    -- Ensure profile exists
    if not EnsureProfileExists(citizenid) then
        return { success = false, message = 'Failed to create profile' }
    end

    local profile = MySQL.single.await('SELECT id FROM mdt_profiles WHERE citizenid = ?', { citizenid })
    if not profile then
        return { success = false, message = 'Failed to create profile' }
    end

    -- Set as profile picture
    MySQL.update.await('UPDATE mdt_profiles SET profilepicture = ? WHERE citizenid = ?', { imageUrl, citizenid })

    -- Add to gallery
    MySQL.insert.await('INSERT INTO mdt_profiles_gallery (profileId, image, label) VALUES (?, ?, ?)', {
        profile.id, imageUrl, 'Profile Photo'
    })

    return { success = true, message = 'Photo uploaded', imageUrl = imageUrl }
end)

-- ============================================================
-- FiveManage Activity Logging (batched)
-- Forwards MDT audit log entries to FiveManage Logs API
-- Docs: https://docs.fivemanage.com/fivemanage/guides/logs/best-practices
-- ============================================================

local LOG_BATCH_SIZE = 50         -- Send when batch reaches this size
local LOG_BATCH_INTERVAL = 5000   -- Or every 5 seconds (ms), whichever comes first
local logBatch = {}
local logBatchTimer = nil

-- Map MDT action names to log levels
local ACTION_LEVELS = {
    -- Errors / critical
    settings_updated = 'warn',
    -- Destructive
    report_deleted   = 'warn',
    case_deleted     = 'warn',
    weapon_deleted   = 'warn',
    evidence_deleted = 'warn',
    icu_deleted      = 'warn',
    -- Default is 'info'
}

local function getLogLevel(action)
    return ACTION_LEVELS[action] or 'info'
end

--- Queue a single log entry for batched delivery to FiveManage
--- @param entry table  { action, actorName, actorCitizenid, entityType, entityId, details }
function FiveManageQueueLog(entry)
    if not FiveManageLogsKey or FiveManageLogsKey == '' then return end

    -- Flatten details to a string to avoid nested objects in metadata
    local detailsStr = nil
    if entry.details then
        local ok, encoded = pcall(json.encode, entry.details)
        detailsStr = ok and encoded or tostring(entry.details)
    end

    logBatch[#logBatch + 1] = {
        level    = getLogLevel(entry.action),
        message  = entry.action,
        resource = resourceName,
        metadata = {
            actorName      = entry.actorName or 'System',
            actorCitizenid = entry.actorCitizenid,
            entityType     = entry.entityType,
            entityId       = entry.entityId,
            details        = detailsStr,
        },
    }

    -- Flush immediately if batch is full
    if #logBatch >= LOG_BATCH_SIZE then
        FiveManageFlushLogs()
    end
end

--- Flush the current log batch to FiveManage
function FiveManageFlushLogs()
    if #logBatch == 0 then return end
    if not FiveManageLogsKey or FiveManageLogsKey == '' then
        logBatch = {}
        return
    end

    -- Take the current batch and reset
    local batch = logBatch
    logBatch = {}

    local payload = json.encode(batch)

    PerformHttpRequest(FiveManageLogsUrl, function(statusCode, responseText)
        if statusCode and statusCode >= 200 and statusCode < 300 then
            -- Success - nothing to do
        else
            ps.warn('FiveManage logs: failed to send batch (' .. #batch .. ' entries) - HTTP ' .. tostring(statusCode))
        end
    end, 'POST', payload, {
        ['Content-Type']  = 'application/json',
        ['Authorization'] = FiveManageLogsKey,
    })
end

-- Periodic flush timer
CreateThread(function()
    while true do
        Wait(LOG_BATCH_INTERVAL)
        if #logBatch > 0 then
            FiveManageFlushLogs()
        end
    end
end)

-- Flush on resource stop to avoid losing buffered logs
AddEventHandler('onResourceStop', function(res)
    if res == resourceName then
        FiveManageFlushLogs()
    end
end)
