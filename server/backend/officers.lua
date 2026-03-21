local resourceName = tostring(GetCurrentResourceName())
local ok, QBCore = pcall(function() return exports['qb-core']:GetCoreObject() end)
if not ok then QBCore = nil end

-- Get player source ID by citizenId
ps.registerCallback(resourceName .. ':server:GetPlayerSourceId', function(source, targetCitizenId)
    if not targetCitizenId then return nil end
    local targetPlayer = ps.getPlayerByIdentifier(targetCitizenId)
    if not targetPlayer then
        ps.notify(source, 'Citizen seems asleep / missing', 'error')
        return nil
    end
    return targetPlayer.source or targetPlayer.PlayerData.source
end)

-- Set Callsign
ps.registerCallback(resourceName .. ':server:setCallsign', function(source, payload)
    local src = source
    if not CheckAuth(src) then return { success = false, message = 'Unauthorized' } end

    payload = payload or {}
    local cid = payload.citizenid or payload.cid
    local newCallsign = payload.callsign or payload.newcallsign

    if not cid or not newCallsign then
        return { success = false, message = 'Missing citizen ID or callsign' }
    end

    if not QBCore then return { success = false, message = 'Core framework not available' } end
    local Player = QBCore.Functions.GetPlayerByCitizenId(cid)
    if Player then
        Player.Functions.SetMetaData('callsign', newCallsign)
        TriggerClientEvent(resourceName .. ':client:updateCallsign', Player.PlayerData.source, newCallsign)

        MySQL.update.await('UPDATE mdt_profiles SET callsign = ? WHERE citizenid = ?', { newCallsign, cid })

        if ps.auditLog then
            ps.auditLog(src, 'callsign_changed', 'officer', cid, { callsign = newCallsign })
        end

        return { success = true, message = 'Callsign updated to ' .. newCallsign }
    end

    return { success = false, message = 'Player must be online to update callsign' }
end)

-- Set Radio Frequency
ps.registerCallback(resourceName .. ':server:setRadio', function(source, payload)
    local src = source
    if not CheckAuth(src) then return { success = false, message = 'Unauthorized' } end

    payload = payload or {}
    local cid = payload.citizenid or payload.cid
    local newRadio = payload.radio or payload.newradio

    if not cid or not newRadio then
        return { success = false, message = 'Missing citizen ID or radio frequency' }
    end

    if not QBCore then return { success = false, message = 'Core framework not available' } end
    local targetPlayer = QBCore.Functions.GetPlayerByCitizenId(cid)
    if not targetPlayer then
        return { success = false, message = 'Officer must be online' }
    end

    local targetSource = targetPlayer.PlayerData.source

    local radio = targetPlayer.Functions.GetItemByName('radio')
    if not radio then
        return { success = false, message = targetPlayer.PlayerData.charinfo.firstname .. ' does not have a radio!' }
    end

    TriggerClientEvent(resourceName .. ':client:setRadio', targetSource, newRadio)
    return { success = true, message = 'Radio set to ' .. newRadio }
end)

-- Get Unit Location (GPS to officer)
ps.registerCallback(resourceName .. ':server:getUnitLocation', function(source, cid)
    if not CheckAuth(source) then return {} end
    if not cid then return {} end

    if not QBCore then return {} end
    local Player = QBCore.Functions.GetPlayerByCitizenId(cid)
    if Player then
        local coords = GetEntityCoords(GetPlayerPed(Player.PlayerData.source))
        return { x = coords.x, y = coords.y, z = coords.z }
    end

    return {}
end)
