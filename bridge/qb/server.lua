if Framework.initials ~= "qb" then return end

Framework.CreateServerCallback = Framework.object.Functions.CreateCallback --[[@as function]]

Framework.GetPlayerByCitizenId = Framework.object.Functions.GetPlayerByCitizenId --[[@as function]]

Framework.GetPlayerByServerId = Framework.object.Functions.GetPlayer --[[@as function]]

Framework.GetPlayerIdentifierByServerId = Framework.object.Functions.GetIdentifier --[[@as function]]

function Framework.GetPlayerCitizenIdByServerId(source)
    local player = Framework.GetPlayerByServerId(source)
    return player?.PlayerData?.citizenid
end

function Framework.GetPlayerCitizenIdByPlayer(player)
    return player?.PlayerData?.citizenid
end

function Framework.GetPlayerServerIdByPlayer(player)
    return player?.PlayerData?.source
end

function Framework.GetPlayerFirstNameByPlayer(player)
    return CapitalFirstLetter(player?.PlayerData?.charinfo?.firstname)
end

function Framework.GetPlayerLastNameByPlayer(player)
    return CapitalFirstLetter(player?.PlayerData?.charinfo?.lastname)
end

function Framework.GetPlayerFullNameByPlayer(player)
    local firstName = Framework.GetPlayerFirstNameByPlayer(player)
    local lastName = Framework.GetPlayerLastNameByPlayer(player)
    return ("%s %s"):format(firstName, lastName)
end

function Framework.GetPlayerLicensesByPlayer(player)
    return player?.PlayerData?.metadata?.licenses
end

function Framework.GetPlayerGenderByPlayer(player)
    return player?.PlayerData?.charinfo?.gender
end

function Framework.GetPlayerPhoneNumberByPlayer(player)
    return player?.PlayerData?.charinfo?.phone
end

function Framework.GetPlayerJobNameByPlayer(player)
    return player?.PlayerData?.job?.name
end

function Framework.GetPlayerJobGradeNameByPlayer(player)
    return player?.PlayerData?.job?.grade?.name
end

function Framework.GetPlayerJobGradeLevelByPlayer(player)
    return player?.PlayerData?.job?.grade?.level
end

function Framework.GetPlayerJobDutyByPlayer(player)
    return player?.PlayerData?.job?.onduty
end

function Framework.GetPlayerJobObjectAsQbByPlayer(player) -- QB Style
    return player?.PlayerData?.job
end

function Framework.GetPlayerCallSignByPlayer(player)
    return player?.PlayerData?.metadata?.callsign
end

function Framework.SetPlayerCallSignByPlayer(player, newCallSign)
    return player?.Functions?.SetMetaData("callsign", newCallSign)
end

function Framework.GetPlayerHasItemByPlayer(player, item)
    return player?.Functions?.GetItemByName(item) and true or false
end

function Framework.RemoveMoneyFromPlayer(player, money, account, reason)
    return player?.Functions?.RemoveMoney(account or "bank", money, reason)
end

function Framework.Notification(source, message, type, duration)
    return TriggerClientEvent("QBCore:Notify", source, message, type, duration)
end