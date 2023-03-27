DB = {}

function DB.GetCitizenID(license)
    return MySQL.query.await("SELECT citizenid FROM players WHERE license = ?", {license})
end

function DB.GetNameFromId(cid) -- CHECK: this looks like it should check for cid instead of citizenid
    local name
    local result = MySQL.scalar.await('SELECT charinfo FROM players WHERE citizenid = @citizenid', { ['@citizenid'] = cid })
    if result ~= nil then
        result = json.decode(result)
        name = result['firstname']..' '..result['lastname']
    end
    return name
end

function DB.GetPlayerVehicles(cid)
    return MySQL.query.await('SELECT id, plate, vehicle FROM player_vehicles WHERE citizenid=:cid', { cid = cid })
end

function DB.GetPlayerProperties(cid)
    return MySQL.query.await('SELECT houselocations.label, houselocations.coords FROM player_houses INNER JOIN houselocations ON player_houses.house = houselocations.name where player_houses.citizenid = ?', {cid})
end

function DB.GetPlayerDataById(id)
    local playerData
    local Player = Framework.GetPlayerByCitizenId(id)
    if Player ~= nil then
        playerData = {citizenid = Player.PlayerData.citizenid, charinfo = Player.PlayerData.charinfo, metadata = Player.PlayerData.metadata, job = Player.PlayerData.job}
    else
        playerData = MySQL.single.await('SELECT citizenid, charinfo, job, metadata FROM players WHERE citizenid = ? LIMIT 1', { id })
    end
    return playerData
end

function DB.GetOwnerName(cid)
    return MySQL.scalar.await('SELECT charinfo FROM `players` WHERE LOWER(`citizenid`) = ? LIMIT 1', {cid})
end

function DB.GetPlayerApartment(cid)
    return MySQL.query.await('SELECT name, type, label FROM apartments where citizenid = ?', {cid})
end

function DB.GetPlayerLicenses(citizenid)
    local licenses = {}
    local Player = Framework.GetPlayerByCitizenId(citizenid)
    if Player ~= nil then
        licenses = Player.PlayerData.metadata.licences
    else
        local result = MySQL.scalar.await('SELECT metadata FROM players WHERE citizenid = @citizenid', {['@citizenid'] = citizenid})
        if result ~= nil then
            local metadata = json.decode(result)
            if metadata["licences"] ~= nil and metadata["licences"] then
                licenses = metadata["licences"]
            else
                licenses = {
                    ['driver'] = false,
                    ['business'] = false,
                    ['weapon'] = false,
                    ['pilot'] = false
                }
            end
        end
    end
    return licenses
end

function DB.ManageLicense(citizenid, type, status)
    local Player = Framework.GetPlayerByCitizenId(citizenid)
    local licenseStatus = nil
    if status == "give" then licenseStatus = true elseif status == "revoke" then licenseStatus = false end
    if Player ~= nil then
        local licences = Player.PlayerData.metadata["licences"]
        licences[type] = licenseStatus
        Player.Functions.SetMetaData("licences", licences)
    else
        local licenseType = '$.licences.'..type
        MySQL.query.await('UPDATE `players` SET `metadata` = JSON_REPLACE(`metadata`, ?, ?) WHERE `citizenid` = ?', {licenseType, licenseStatus, citizenid}) --seems to not work on older MYSQL versions, think about alternative
    end
end

function DB.UpdateAllLicenses(citizenid, incomingLicenses)
    local Player = Framework.GetPlayerByCitizenId(citizenid)
    if Player ~= nil then
        Player.Functions.SetMetaData("licences", incomingLicenses)
    else
        local result = MySQL.scalar.await('SELECT metadata FROM players WHERE citizenid = @citizenid', {['@citizenid'] = citizenid})
        result = json.decode(result)

        result.licences = result.licences or {
            ['driver'] = true, -- CHECK: are you sure this needs to remains true?
            ['business'] = false,
            ['weapon'] = false,
            ['pilot'] = false
        }

        for k, _ in pairs(incomingLicenses) do
            result.licences[k] = incomingLicenses[k]
        end
        MySQL.query.await('UPDATE `players` SET `metadata` = @metadata WHERE citizenid = @citizenid', {['@metadata'] = json.encode(result), ['@citizenid'] = citizenid})
    end
end