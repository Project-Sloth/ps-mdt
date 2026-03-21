local resourceName = tostring(GetCurrentResourceName())

local dispatchMessages = {}

-- Send dispatch message
ps.registerCallback(resourceName .. ':server:sendDispatchMessage', function(source, payload)
    local src = source
    if not CheckAuth(src) then return { success = false, message = 'Unauthorized' } end

    payload = payload or {}
    local message = payload.message
    local time = payload.time

    if not message or message == '' then
        return { success = false, message = 'Empty message' }
    end

    local citizenid = ps.getIdentifier(src)
    local callsign = ps.getMetadata(src, 'callsign') or '000'
    local name = ps.getPlayerName(src) or 'Unknown'

    local pfp = MySQL.scalar.await('SELECT profilepicture FROM mdt_profiles WHERE citizenid = ? LIMIT 1', { citizenid })

    local item = {
        profilepic = pfp or '',
        callsign = callsign,
        cid = citizenid,
        name = '(' .. callsign .. ') ' .. name,
        message = message,
        time = time or os.date('%H:%M'),
    }

    dispatchMessages[#dispatchMessages + 1] = item
    TriggerClientEvent(resourceName .. ':client:dispatchMessage', -1, item)

    return { success = true }
end)

-- Get dispatch messages
ps.registerCallback(resourceName .. ':server:getDispatchMessages', function(source)
    if not CheckAuth(source) then return {} end
    return dispatchMessages
end)

-- Get call responses from ps-dispatch
ps.registerCallback(resourceName .. ':server:getCallResponses', function(source, callid)
    if not CheckAuth(source) then return {} end

    if GetResourceState('ps-dispatch') == 'started' then
        local calls = exports['ps-dispatch']:GetDispatchCalls()
        if calls and calls[callid] and calls[callid]['responses'] then
            return calls[callid]['responses']
        end
    end

    return {}
end)

-- Send call response
ps.registerCallback(resourceName .. ':server:sendCallResponse', function(source, payload)
    local src = source
    if not CheckAuth(src) then return { success = false } end

    payload = payload or {}
    local message = payload.message
    local time = payload.time
    local callid = payload.callid

    if not message or not callid then
        return { success = false }
    end

    local name = ps.getPlayerName(src) or 'Unknown'

    if GetResourceState('ps-dispatch') == 'started' then
        TriggerEvent('dispatch:sendCallResponse', src, callid, message, time, function(isGood)
            if isGood then
                TriggerClientEvent(resourceName .. ':client:callResponse', -1, message, time, callid, name)
            end
        end)
    end

    return { success = true }
end)

-- Signal 100 (Panic / Emergency)
ps.registerCallback(resourceName .. ':server:signal100', function(source, payload)
    local src = source
    if not CheckAuth(src) then return { success = false, message = 'Unauthorized' } end

    payload = payload or {}
    local radio = payload.radio or '1'
    local active = payload.active

    if active == nil then active = true end

    TriggerClientEvent(resourceName .. ':client:sig100', -1, radio, active)

    if ps.auditLog then
        ps.auditLog(src, active and 'signal100_activated' or 'signal100_deactivated', 'dispatch', radio, {})
    end

    return { success = true, message = active and 'Signal 100 activated' or 'Signal 100 cleared' }
end)

-- Attached Units Query
ps.registerCallback(resourceName .. ':server:getAttachedUnits', function(source, callid)
    if not CheckAuth(source) then return {} end
    if not callid then return {} end

    if GetResourceState('ps-dispatch') == 'started' then
        local calls = exports['ps-dispatch']:GetDispatchCalls()
        if calls then
            for i = 1, #calls do
                if calls[i] and calls[i]['id'] == tonumber(callid) then
                    return calls[i]['units'] or {}
                end
            end
        end
    end

    return {}
end)
