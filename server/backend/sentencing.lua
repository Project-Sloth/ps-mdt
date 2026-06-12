local resourceName = tostring(GetCurrentResourceName())
local ok, QBCore = pcall(function() return exports['qb-core']:GetCoreObject() end)
if not ok then QBCore = nil end

-- Send to Jail
ps.registerCallback(resourceName .. ':server:sendToJail', function(source, payload)
    local src = source
    if not CheckAuth(src) then return { success = false, message = 'Unauthorized' } end
    if not CheckPermission(src, 'charges_edit') then
        return { success = false, message = 'Insufficient permissions' }
    end

    payload = payload or {}
    local citizenId = payload.citizenId
    local sentence = tonumber(payload.sentence)

    if not citizenId or not sentence or sentence <= 0 then
        return { success = false, message = 'Missing citizen ID or invalid sentence' }
    end

    local maxSentence = (Config and Config.Fines and Config.Fines.MaxSentence) or 999
    if sentence > maxSentence then
        return { success = false, message = 'Sentence exceeds maximum of ' .. maxSentence .. ' months' }
    end

    local targetPlayer = ps.getPlayerByIdentifier(citizenId)
    if not targetPlayer then
        return { success = false, message = 'Player must be online to send to jail' }
    end

    local targetSource = targetPlayer.source or (targetPlayer.PlayerData and targetPlayer.PlayerData.source)
    if not targetSource then
        return { success = false, message = 'Could not resolve player source' }
    end

    local OtherPlayer = QBCore and QBCore.Functions.GetPlayer(targetSource)
    if not OtherPlayer then
        return { success = false, message = 'Could not find target player' }
    end

    local currentDate = os.date('*t')
    if currentDate.day == 31 then
        currentDate.day = 30
    end

    OtherPlayer.Functions.SetMetaData('injail', sentence)
    OtherPlayer.Functions.SetMetaData('criminalrecord', {
        ['hasRecord'] = true,
        ['date'] = currentDate
    })
    TriggerClientEvent('police:client:SendToJail', targetSource, sentence)
    ps.notify(src, 'Sent to jail for ' .. sentence .. ' months', 'success')

    if ps.auditLog then
        ps.auditLog(src, 'sent_to_jail', 'citizen', citizenId, {
            sentence = sentence,
        })
    end

    return { success = true, message = 'Sent to jail for ' .. sentence .. ' months' }
end)

ps.registerCallback(resourceName .. ':server:giveCitation', function(source, payload)
    local src = source
    if not CheckAuth(src) then return { success = false, message = 'Unauthorized' } end
    if not CheckPermission(src, 'charges_edit') then
        return { success = false, message = 'Insufficient permissions' }
    end

    payload = payload or {}
    local citizenId = payload.citizenId
    local fine = tonumber(payload.fine)
    local reportId = payload.reportId

    if not citizenId then
        return { success = false, message = 'Missing citizen ID' }
    end
    if not fine or fine ~= fine or fine <= 0 then
        return { success = false, message = 'Invalid fine amount' }
    end
    fine = math.floor(fine)

    local Player = ps.getPlayerByIdentifier(citizenId)
    if not Player then
        return { success = false, message = 'Player must be online to issue a fine' }
    end

    local playerSrc = Player.source or (Player.PlayerData and Player.PlayerData.source)
    if not playerSrc then
        return { success = false, message = 'Could not resolve player source' }
    end

    local removed = ps.removeMoney(playerSrc, 'bank', fine, 'mdt-fine')
    if not removed then
        return { success = false, message = 'Could not deduct fine (insufficient funds)' }
    end

    ps.notify(playerSrc, '$' .. fine .. ' fine deducted from your bank account', 'error')
    ps.notify(src, '$' .. fine .. ' fine issued successfully', 'success')

    if ps.auditLog then
        local officerName = ps.getPlayerName(src) or 'Unknown Officer'
        ps.auditLog(src, 'fine_issued', 'citizen', citizenId, {
            fine = fine,
            reportId = reportId,
            officerName = officerName,
        })
    end

    return { success = true, message = '$' .. fine .. ' fine issued' }
end)
