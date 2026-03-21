local resourceName = tostring(GetCurrentResourceName())

-- Set Callsign
RegisterNUICallback('setCallsign', function(data, cb)
    if not MDTOpen then
        cb({ success = false, message = 'MDT is not open' })
        return
    end

    if type(data) ~= 'table' or (not data.cid and not data.citizenid) or (not data.newcallsign and not data.callsign) then
        cb({ success = false, message = 'Missing citizen ID or callsign' })
        return
    end

    local result = ps.callback(resourceName .. ':server:setCallsign', {
        citizenid = data.cid or data.citizenid,
        callsign = data.newcallsign or data.callsign,
    })
    cb(result or { success = false, message = 'Failed to set callsign' })
end)

-- Set Radio Frequency
RegisterNUICallback('setRadio', function(data, cb)
    if not MDTOpen then
        cb({ success = false, message = 'MDT is not open' })
        return
    end

    if type(data) ~= 'table' or (not data.cid and not data.citizenid) or (not data.newradio and not data.radio) then
        cb({ success = false, message = 'Missing citizen ID or radio frequency' })
        return
    end

    local result = ps.callback(resourceName .. ':server:setRadio', {
        citizenid = data.cid or data.citizenid,
        radio = data.newradio or data.radio,
    })
    cb(result or { success = false, message = 'Failed to set radio' })
end)

-- Radio set event from server
RegisterNetEvent(resourceName .. ':client:setRadio')
AddEventHandler(resourceName .. ':client:setRadio', function(radio)
    if type(tonumber(radio)) == 'number' then
        local success = pcall(function()
            exports['pma-voice']:setVoiceProperty('radioEnabled', true)
            exports['pma-voice']:setRadioChannel(tonumber(radio))
        end)
        if success then
            ps.notify('Radio frequency set to ' .. radio, 'success')
        else
            ps.notify('Failed to set radio - pma-voice not available', 'error')
        end
    else
        ps.notify('Invalid radio frequency', 'error')
    end
end)

-- Set Waypoint to Unit (GPS to another officer)
RegisterNUICallback('setWaypointU', function(data, cb)
    if not MDTOpen then cb('ok') return end
    local coords = ps.callback(resourceName .. ':server:getUnitLocation', data.cid)
    if coords then
        SetNewWaypoint(coords.x, coords.y)
        ps.notify('GPS set to officer location', 'success')
    else
        ps.notify('Officer not found or offline', 'error')
    end
    cb('ok')
end)

-- House Waypoint (Set GPS to property)
RegisterNUICallback('SetHouseLocation', function(data, cb)
    if not MDTOpen then cb('ok') return end
    if data.coord and data.coord[1] then
        local coords = {}
        for word in data.coord[1]:gmatch('[^,%s]+') do
            coords[#coords + 1] = tonumber(word)
        end
        if coords[1] and coords[2] then
            SetNewWaypoint(coords[1], coords[2])
            ps.notify('GPS set to property location', 'success')
        end
    elseif data.x and data.y then
        SetNewWaypoint(data.x, data.y)
        ps.notify('GPS set to property location', 'success')
    end
    cb('ok')
end)
