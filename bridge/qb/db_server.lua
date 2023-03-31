DB = {}

function DB.GetCitizenIDByLicense(license)
    return MySQL.query.await("SELECT citizenid FROM players WHERE license = ?", {license})
end

function DB.GetNameFromCitizenId(citizenId)
    local name
    local result = MySQL.scalar.await("SELECT charinfo FROM players WHERE citizenid = @citizenid", { ["@citizenid"] = citizenId })
    if result ~= nil then
        result = json.decode(result)
        name = ("%s %s"):format(CapitalFirstLetter(result["firstname"]), CapitalFirstLetter(result["lastname"]))
    end
    return name
end

function DB.GetPlayerVehicles(cid)
    return MySQL.query.await("SELECT id, plate, vehicle FROM player_vehicles WHERE citizenid=:cid", { cid = cid })
end

function DB.GetPlayerPropertiesByCitizenId(cid)
    return MySQL.query.await("SELECT houselocations.label, houselocations.coords FROM player_houses INNER JOIN houselocations ON player_houses.house = houselocations.name where player_houses.citizenid = ?", {cid})
end

function DB.GetPlayerDataByCitizenId(id)
    local playerData
    local Player = Framework.GetPlayerByCitizenId(id)
    if Player ~= nil then
        playerData = {citizenid = Player.PlayerData.citizenid, charinfo = Player.PlayerData.charinfo, metadata = Player.PlayerData.metadata, job = Player.PlayerData.job}
    else
        playerData = MySQL.single.await("SELECT citizenid, charinfo, job, metadata FROM players WHERE citizenid = ? LIMIT 1", { id })
    end
    return playerData
end

function DB.GetOwnerName(cid)
    return MySQL.scalar.await("SELECT charinfo FROM `players` WHERE LOWER(`citizenid`) = ? LIMIT 1", {cid})
end

function DB.GetPlayerApartmentByCitizenId(citizenid)
    local apartmentData = MySQL.query.await("SELECT name, type, label FROM apartments where citizenid = ?", {citizenid})
    if Config.UsingDefaultQBApartments and apartmentData then
        apartmentData = ("%s (%s)"):format(apartmentData[1].label, apartmentData[1].name)
    end
    return apartmentData
end

function DB.GetPlayerLicenses(citizenid)
    local licenses = {}
    local Player = Framework.GetPlayerByCitizenId(citizenid)
    if Player ~= nil then
        licenses = Player.PlayerData.metadata.licences
    else
        local result = MySQL.scalar.await("SELECT metadata FROM players WHERE citizenid = @citizenid", {["@citizenid"] = citizenid})
        if result ~= nil then
            local metadata = json.decode(result)
            if metadata["licences"] ~= nil and metadata["licences"] then
                licenses = metadata["licences"]
            else
                licenses = {
                    ["driver"] = false,
                    ["business"] = false,
                    ["weapon"] = false,
                    ["pilot"] = false
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
        local licenseType = "$.licences."..type
        MySQL.query.await("UPDATE `players` SET `metadata` = JSON_REPLACE(`metadata`, ?, ?) WHERE `citizenid` = ?", {licenseType, licenseStatus, citizenid}) --seems to not work on older MYSQL versions, think about alternative
    end
end

function DB.UpdateAllLicenses(citizenid, incomingLicenses)
    local Player = Framework.GetPlayerByCitizenId(citizenid)
    if Player ~= nil then
        Player.Functions.SetMetaData("licences", incomingLicenses)
    else
        local result = MySQL.scalar.await("SELECT metadata FROM players WHERE citizenid = @citizenid", {["@citizenid"] = citizenid})
        result = json.decode(result)

        result.licences = result.licences or {
            ["driver"] = true, -- CHECK: are you sure this needs to remains true?
            ["business"] = false,
            ["weapon"] = false,
            ["pilot"] = false
        }

        for k, _ in pairs(incomingLicenses) do
            result.licences[k] = incomingLicenses[k]
        end
        MySQL.query.await("UPDATE `players` SET `metadata` = @metadata WHERE citizenid = @citizenid", {["@metadata"] = json.encode(result), ["@citizenid"] = citizenid})
    end
end

function DB.SearchAllPlayersByData(data, jobType)
    return MySQL.query.await("SELECT p.citizenid, p.charinfo, md.pfp FROM players p LEFT JOIN mdt_data md on p.citizenid = md.cid WHERE LOWER(CONCAT(JSON_VALUE(p.charinfo, \"$.firstname\"), \" \", JSON_VALUE(p.charinfo, \"$.lastname\"))) LIKE :query OR LOWER(`charinfo`) LIKE :query OR LOWER(`citizenid`) LIKE :query AND jobtype = :jobtype LIMIT 20", { query = string.lower("%"..data.."%"), jobtype = jobType })
end

function DB.SearchPlayerIncidentByData(data, jobType)
    return MySQL.query.await("SELECT p.citizenid, p.charinfo, p.metadata, md.pfp from players p LEFT JOIN mdt_data md on p.citizenid = md.cid WHERE LOWER(`charinfo`) LIKE :query OR LOWER(`citizenid`) LIKE :query AND `jobtype` = :jobtype LIMIT 30", {
        query = string.lower("%"..data.."%"), -- % wildcard, needed to search for all alike results
        jobtype = jobType
    })
end

function DB.SearchAllVehiclesByData(data)
    return MySQL.query.await("SELECT pv.id, pv.citizenid, pv.plate, pv.vehicle, pv.mods, pv.state, p.charinfo FROM `player_vehicles` pv LEFT JOIN players p ON pv.citizenid = p.citizenid WHERE LOWER(`plate`) LIKE :query OR LOWER(`vehicle`) LIKE :query LIMIT 25", {
        query = string.lower("%"..data.."%")
    })
end

function DB.SearchVehicleDataByPlate(plate)
    return MySQL.query.await("select pv.*, p.charinfo from player_vehicles pv LEFT JOIN players p ON pv.citizenid = p.citizenid where pv.plate = :plate LIMIT 1", { plate = TrimString(plate)})
end

function DB.GetVehicleWarrantStatusByPlate(plate)
    local result = MySQL.query.await("SELECT p.plate, p.citizenid, m.id FROM player_vehicles p INNER JOIN mdt_convictions m ON p.citizenid = m.cid WHERE m.warrant =1 AND p.plate =?", {plate})
    if result and result[1] then
        local citizenid = result[1]["citizenid"]
        local owner = DB.GetNameFromCitizenId(citizenid)
        local incidentId = result[1]["id"]
        return true, owner, incidentId
    end
    return false
end

function DB.GetVehicleOwnerByPlate(plate)
    local result = MySQL.query.await("SELECT plate, citizenid, id FROM player_vehicles WHERE plate = @plate", {["@plate"] = plate})
    if result and result[1] then
        local citizenid = result[1]["citizenid"]
        local owner = DB.GetNameFromCitizenId(citizenid)
        return owner
    end
    return nil
end