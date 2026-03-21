local resourceName = tostring(GetCurrentResourceName())
local ok, QBCore = pcall(function() return exports['qb-core']:GetCoreObject() end)
if not ok then QBCore = nil end

-- Send to Jail
ps.registerCallback(resourceName .. ':server:sendToJail', function(source, payload)
    local src = source
    if not CheckAuth(src) then return { success = false, message = 'Unauthorized' } end

    payload = payload or {}
    local citizenId = payload.citizenId
    local sentence = tonumber(payload.sentence)

    if not citizenId or not sentence or sentence <= 0 then
        return { success = false, message = 'Missing citizen ID or invalid sentence' }
    end

    local targetPlayer = ps.getPlayerByIdentifier(citizenId)
    if not targetPlayer then
        return { success = false, message = 'Player must be online to send to jail' }
    end

    local targetSource = targetPlayer.source or targetPlayer.PlayerData.source

    if Config.UseCQCMugshot then
        TriggerClientEvent(resourceName .. ':client:triggerMugshot', targetSource)
        Wait(5000)
    end

    TriggerEvent('police:server:JailPlayer', targetSource, sentence)

    if ps.auditLog then
        ps.auditLog(src, 'sent_to_jail', 'citizen', citizenId, {
            sentence = sentence,
        })
    end

    return { success = true, message = 'Sent to jail for ' .. sentence .. ' months' }
end)

-- Give Citation Item
local function giveCitationItem(src, citizenId, fine, reportId)
    if not QBCore then return false end
    local Player = QBCore.Functions.GetPlayerByCitizenId(citizenId)
    if not Player then return false end

    local Officer = QBCore.Functions.GetPlayer(src)
    if not Officer then return false end

    local PlayerName = Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname
    local OfficerFullName = '(' .. (Officer.PlayerData.metadata.callsign or '000') .. ') ' .. Officer.PlayerData.charinfo.firstname .. ' ' .. Officer.PlayerData.charinfo.lastname
    local date = os.date('%Y-%m-%d %H:%M')

    local info = {
        citizenId = citizenId,
        fine = '$' .. fine,
        date = date,
        incidentId = '#' .. (reportId or 'N/A'),
        officer = OfficerFullName,
    }

    local success = pcall(function()
        Player.Functions.AddItem('mdtcitation', 1, false, info)
    end)

    if success then
        ps.notify(src, PlayerName .. ' (' .. citizenId .. ') received a citation!', 'success')
        TriggerClientEvent('inventory:client:ItemBox', Player.PlayerData.source, QBCore.Shared.Items['mdtcitation'], 'add')
    end

    return success
end

ps.registerCallback(resourceName .. ':server:giveCitation', function(source, payload)
    local src = source
    if not CheckAuth(src) then return { success = false, message = 'Unauthorized' } end

    payload = payload or {}
    local citizenId = payload.citizenId
    local fine = tonumber(payload.fine) or 0
    local reportId = payload.reportId

    if not citizenId then
        return { success = false, message = 'Missing citizen ID' }
    end

    local result = giveCitationItem(src, citizenId, fine, reportId)
    return { success = result, message = result and 'Citation given' or 'Failed to give citation' }
end)
