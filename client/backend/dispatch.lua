local resourceName = tostring(GetCurrentResourceName())
local coolDown = false

-- Send dispatch message
RegisterNUICallback('dispatchMessage', function(data, cb)
    if not MDTOpen then cb({ success = false }) return end

    local result = ps.callback(resourceName .. ':server:sendDispatchMessage', {
        message = data.message,
        time = data.time,
    })
    cb(result or { success = false })
end)

-- Refresh dispatch messages
RegisterNUICallback('refreshDispatchMsgs', function(data, cb)
    if not MDTOpen then cb({}) return end
    local messages = ps.callback(resourceName .. ':server:getDispatchMessages')
    cb(messages or {})
end)

-- Get call responses
RegisterNUICallback('getCallResponses', function(data, cb)
    if not MDTOpen then cb({}) return end
    local responses = ps.callback(resourceName .. ':server:getCallResponses', data.callid or data.id)
    cb(responses or {})
end)

-- Send call response
RegisterNUICallback('sendCallResponse', function(data, cb)
    if not MDTOpen then cb({ success = false }) return end
    local result = ps.callback(resourceName .. ':server:sendCallResponse', {
        message = data.message,
        time = data.time,
        callid = data.callid,
    })
    cb(result or { success = false })
end)

-- Dispatch message received from server
RegisterNetEvent(resourceName .. ':client:dispatchMessage')
AddEventHandler(resourceName .. ':client:dispatchMessage', function(sentData)
    if ps.getJobType() == 'leo' then
        SendNUI('dispatchMessage', sentData)
    end
end)

-- Call response received from server
RegisterNetEvent(resourceName .. ':client:callResponse')
AddEventHandler(resourceName .. ':client:callResponse', function(message, time, callid, name)
    SendNUI('callResponse', {
        message = message,
        time = time,
        callid = callid,
        name = name,
    })
end)

-- Signal 100 (Panic / Emergency)
RegisterNUICallback('signal100', function(data, cb)
    if not MDTOpen then cb({ success = false }) return end

    local result = ps.callback(resourceName .. ':server:signal100', {
        radio = data.radio,
        active = data.active,
    })
    cb(result or { success = false })
end)

-- Signal 100 event from server
RegisterNetEvent(resourceName .. ':client:sig100')
AddEventHandler(resourceName .. ':client:sig100', function(radio, isActive)
    if ps.getJobType() ~= 'leo' then return end
    if not ps.getJobDuty() then return end

    if isActive then
        ps.notify('Radio ' .. tostring(radio) .. ' is currently Signal 100!', 'error')
    else
        ps.notify('Radio ' .. tostring(radio) .. ' Signal 100 cleared', 'success')
    end

    SendNUI('signal100', { radio = radio, active = isActive })
end)

-- Remove Dispatch Call Blip
RegisterNUICallback('removeCallBlip', function(data, cb)
    if not MDTOpen then cb('ok') return end
    local callid = data.callid or data.id
    if callid and GetResourceState('ps-dispatch') == 'started' then
        TriggerEvent('ps-dispatch:client:removeCallBlip', callid)
    end
    cb('ok')
end)

-- Dispatch Notification Handler (callsign mention detection)
RegisterNUICallback('dispatchNotif', function(data, cb)
    local info = data.data or data
    local mentioned = false

    -- Access callSign from officers.lua scope - use metadata fallback
    local currentCallSign = ps.getMetadata and ps.getMetadata('callsign') or ''

    if currentCallSign ~= '' and info.message then
        if string.find(string.lower(info.message), string.lower(string.gsub(currentCallSign, '-', '%%-'))) then
            mentioned = true
        end
    end

    if mentioned then
        ps.notify('Dispatch (Mention): ' .. (info.message or ''), 'info')
        PlaySoundFrontend(-1, 'SELECT', 'HUD_FRONTEND_DEFAULT_SOUNDSET', false)
        PlaySoundFrontend(-1, 'Event_Start_Text', 'GTAO_FM_Events_Soundset', false)
    end

    cb(true)
end)

-- Attached Units Query
RegisterNUICallback('attachedUnits', function(data, cb)
    local callid = data.callid or data.id
    local units = ps.callback(resourceName .. ':server:getAttachedUnits', callid)
    cb(units or {})
end)

-- Traffic Stop Integration (Wolfknight Radar)
if Config.UseWolfknightRadar then
    local function getStreetAndZone(coords)
        local zone = GetLabelText(GetNameOfZone(coords.x, coords.y, coords.z))
        local currentStreetHash = GetStreetNameAtCoord(coords.x, coords.y, coords.z)
        local currentStreetName = GetStreetNameFromHashKey(currentStreetHash)
        return currentStreetName .. ', ' .. zone
    end

    local function getVehicleName(vehicle)
        return GetLabelText(GetDisplayNameFromVehicleModel(GetEntityModel(vehicle)))
    end

    RegisterNetEvent(resourceName .. ':client:trafficStop')
    AddEventHandler(resourceName .. ':client:trafficStop', function()
        if not IsPedInAnyPoliceVehicle(PlayerPedId()) then
            ps.notify('Not in a police vehicle!', 'error')
            return
        end

        if coolDown then
            ps.notify('Traffic stop cooldown active!', 'error')
            return
        end

        local currentPos = GetEntityCoords(PlayerPedId())
        local locationInfo = getStreetAndZone(currentPos)

        local success, data = pcall(function()
            return exports['wk_wars2x']:GetFrontPlate()
        end)

        if not success or not data or not data.veh or data.veh == 0 then
            ps.notify('No vehicle detected by radar', 'error')
            return
        end

        local vehicleName = getVehicleName(data.veh)
        local plate = data.plate

        if GetResourceState('ps-dispatch') == 'started' then
            local playerData = ps.getPlayerData()
            local charinfo = playerData and playerData.charinfo or {}
            local job = playerData and playerData.job or {}
            local gradeName = job.grade and job.grade.name or ''

            exports['ps-dispatch']:CustomAlert({
                coords = { x = currentPos.x, y = currentPos.y, z = currentPos.z },
                message = 'Ongoing Traffic Stop',
                dispatchCode = '10-11',
                description = 'Ongoing Traffic Stop',
                firstStreet = locationInfo,
                model = vehicleName,
                plate = plate,
                name = gradeName .. ', ' .. (charinfo.firstname or '') .. ' ' .. (charinfo.lastname or ''),
                radius = 0,
                sprite = 60,
                color = 3,
                scale = 1.0,
                length = 3,
            })
        end

        coolDown = true
        SetTimeout(15000, function()
            coolDown = false
        end)
    end)
end
