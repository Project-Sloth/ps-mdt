local resourceName = tostring(GetCurrentResourceName())

-- Civilian self-profile (no MDTOpen check needed, civilians don't use full MDT)
RegisterNUICallback('getMyProfile', function(data, cb)
    local result = ps.callback(resourceName .. ':server:getMyProfile')
    cb(result or { success = false })
end)

RegisterNUICallback('getCitizens', function(data, cb)
    if not MDTOpen then cb({}) return end
    if type(data) ~= 'table' then
        data = {page = 1}
    end
    local page = data.page or 1 -- Default to page 1 if not provided
    local ok, result = pcall(ps.callback, resourceName..':server:getCitizens', page)
    if not ok or type(result) ~= 'table' then
        ps.warn('[getCitizens] Server callback failed: ' .. tostring(result))
        cb({})
        return
    end
    ps.debug(('[getCitizens] Triggered NUI callback on client for page %d'):format(page), result)
    cb(result)
end)

RegisterNUICallback('searchCitizens', function(data, cb)
    if not MDTOpen then cb({}) return end
    if not data or not data.query then
        cb({})
        return
    end
    local query = tostring(data.query)
    if #query < 2 then
        cb({})
        return
    end
    local result = ps.callback(resourceName..':server:searchCitizens', query)
    cb(result)
end)

RegisterNUICallback('getBolos', function(data, cb)
    if not MDTOpen then cb({}) return end
    local boloType = 'citizen'
    local boloStatus = nil
    if type(data) == 'table' then
        if data.type and data.type ~= '' then
            boloType = data.type
        end
        if data.status and data.status ~= '' then
            boloStatus = data.status
        end
    end
    if boloType == 'all' then
        boloStatus = boloStatus or 'all'
    end
    local result = ps.callback(resourceName..':server:getBOLO', boloType, boloStatus)
    ps.debug('[getBolos] Fetched BOLOs:', result)
    cb(result)
end)

RegisterNUICallback('createBolo', function(data, cb)
    if not MDTOpen then cb({ success = false }) return end
    local result = ps.callback(resourceName .. ':server:createBolo', data)
    cb(result or { success = false })
end)

RegisterNUICallback('deleteBolo', function(data, cb)
    if not MDTOpen then cb({ success = false }) return end
    if not data or not data.id then
        cb({ success = false, message = 'Missing BOLO ID' })
        return
    end
    local result = ps.callback(resourceName .. ':server:deleteBolo', data)
    cb(result or { success = false })
end)

RegisterNUICallback('updateBoloStatus', function(data, cb)
    if not MDTOpen then cb({ success = false }) return end
    if not data or not data.id or not data.status then
        cb({ success = false, message = 'Missing BOLO ID or status' })
        return
    end
    local result = ps.callback(resourceName .. ':server:updateBoloStatus', data)
    cb(result or { success = false })
end)

RegisterNUICallback('viewBolo', function(data, cb)
    cb({})
    if data and data.boloId then
        TriggerServerEvent(resourceName..':server:viewBolo', data.boloId)
    end
end)

RegisterNetEvent('ps-mdt:client:viewReport', function(reportId)
    if not reportId then return end
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'viewReport', reportId = tostring(reportId) })
end)

RegisterNUICallback('getCitizen', function(data, cb)
    if not MDTOpen then cb({}) return end
    if not data or not data.citizenid then
        cb({ success = false, message = 'Missing citizen id' })
        return
    end

    local result = ps.callback(resourceName .. ':server:getCitizenProfile', data.citizenid)
    if result then
        cb(result)
    else
        cb({ success = false, message = 'Citizen not found' })
    end
end)

RegisterNUICallback('updateCitizenLicense', function(data, cb)
    if not MDTOpen then cb({ success = false, message = 'MDT is not open' }) return end
    if not data or not data.citizenid or not data.license then
        cb({ success = false, message = 'Missing citizen id or license' })
        return
    end

    local result = ps.callback(resourceName .. ':server:updateCitizenLicense', data)
    if result then
        cb(result)
    else
        cb({ success = false, message = 'Failed to update license' })
    end
end)

RegisterNUICallback('updateCitizenCustomLicense', function(data, cb)
    if not MDTOpen then cb({ success = false, message = 'MDT is not open' }) return end
    if not data or not data.citizenid or not data.licenseId then
        cb({ success = false, message = 'Missing citizen id or license id' })
        return
    end
    local result = ps.callback(resourceName .. ':server:updateCitizenCustomLicense', data)
    cb(result or { success = false, message = 'Failed to update custom license' })
end)

RegisterNUICallback('updateCitizen', function(data, cb)
    if not MDTOpen then cb({ success = false, message = 'MDT is not open' }) return end
    if not data or not data.citizenid then
        cb({ success = false, message = 'Missing citizen id' })
        return
    end
    local result = ps.callback(resourceName .. ':server:updateCitizen', data)
    cb(result or { success = false, message = 'Failed to update citizen' })
end)

RegisterNUICallback('addCitizenTag', function(data, cb)
    if not MDTOpen then cb({ success = false }) return end
    if not data or not data.citizenid or not data.tag then
        cb({ success = false, message = 'Missing citizen id or tag' })
        return
    end
    local result = ps.callback(resourceName .. ':server:addCitizenTag', data)
    cb(result or { success = false })
end)

RegisterNUICallback('removeCitizenTag', function(data, cb)
    if not MDTOpen then cb({ success = false }) return end
    if not data or not data.citizenid or not data.tag then
        cb({ success = false, message = 'Missing citizen id or tag' })
        return
    end
    local result = ps.callback(resourceName .. ':server:removeCitizenTag', data)
    cb(result or { success = false })
end)

RegisterNUICallback('addCitizenGallery', function(data, cb)
    if not MDTOpen then cb({ success = false }) return end
    if not data or not data.citizenid or not data.image then
        cb({ success = false, message = 'Missing citizen id or image' })
        return
    end
    local result = ps.callback(resourceName .. ':server:addCitizenGallery', data)
    cb(result or { success = false })
end)

RegisterNUICallback('removeCitizenGallery', function(data, cb)
    if not MDTOpen then cb({ success = false }) return end
    if not data or not data.citizenid or not data.image then
        cb({ success = false, message = 'Missing citizen id or image' })
        return
    end
    local result = ps.callback(resourceName .. ':server:removeCitizenGallery', data)
    cb(result or { success = false })
end)

-- Update citizen fingerprint
RegisterNUICallback('updateCitizenFingerprint', function(data, cb)
    if not MDTOpen then cb({ success = false }) return end
    if not data or not data.citizenid then
        cb({ success = false, message = 'Missing citizen id' })
        return
    end
    local result = ps.callback(resourceName .. ':server:updateCitizenFingerprint', data.citizenid, data.fingerprint or '')
    cb(result or { success = false })
end)

-- Update citizen DNA
RegisterNUICallback('updateCitizenDNA', function(data, cb)
    if not MDTOpen then cb({ success = false }) return end
    if not data or not data.citizenid then
        cb({ success = false, message = 'Missing citizen id' })
        return
    end
    local result = ps.callback(resourceName .. ':server:updateCitizenDNA', data.citizenid, data.dna or '')
    cb(result or { success = false })
end)

-- Add fingerprint to a suspect's record
RegisterNUICallback('addSuspectFingerprint', function(data, cb)
    if not MDTOpen then cb({ success = false }) return end
    if not data or not data.citizenid then
        cb({ success = false, message = 'Missing citizen id' })
        return
    end
    local result = ps.callback(resourceName .. ':server:addSuspectFingerprint', data.citizenid)
    cb(result or { success = false, message = 'Failed to add fingerprint' })
end)

-- Capture mugshot from officer's view (hide MDT, screenshot, upload, re-show MDT)
RegisterNUICallback('triggerSuspectMugshot', function(data, cb)
    if not data or not data.citizenid then
        cb({ success = false, message = 'Missing citizen id' })
        return
    end
    CreateThread(function()
        local ok, imageUrl = pcall(CaptureMugshot, data.citizenid)
        if ok and imageUrl then
            cb({ success = true, message = 'Mugshot captured', imageUrl = imageUrl })
        else
            cb({ success = false, message = 'Failed to capture mugshot' })
        end
    end)
end)

-- Upload a profile photo for a suspect via base64
RegisterNUICallback('uploadSuspectPhoto', function(data, cb)
    if not MDTOpen then cb({ success = false }) return end
    if not data or not data.citizenid or not data.image then
        cb({ success = false, message = 'Missing citizen id or image data' })
        return
    end
    local result = ps.callback(resourceName .. ':server:uploadSuspectPhoto', data.citizenid, data.image)
    cb(result or { success = false, message = 'Failed to upload photo' })
end)
