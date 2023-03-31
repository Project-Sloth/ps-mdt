-- Get CitizenIDs from Player License
function GetCitizenIDByLicense(license)
    local result = DB?.GetCitizenIDByLicense(license)
    if result == nil then print("Cannot find a CitizenID for License: "..license) end
    return result
end

-- (Start) Opening the MDT and sending data
function AddLog(text)
    --print(text)
    return MySQL.insert.await('INSERT INTO `mdt_logs` (`text`, `time`) VALUES (?,?)', {text, os.time() * 1000})
    -- return exports.oxmysql:execute('INSERT INTO `mdt_logs` (`text`, `time`) VALUES (:text, :time)', { text = text, time = os.time() * 1000 })
end

function GetNameFromCitizenId(citizenId)
    local result = DB?.GetNameFromCitizenId(citizenId)
    if result == nil then print("Cannot find a name for CID: "..citizenId) end
    return result
end

-- idk what this is used for either
function GetPersonInformation(cid, jobtype)
    local result = MySQL.query.await('SELECT information, tags, gallery, pfp FROM mdt_data WHERE cid = ? and jobtype = ?', { cid,  jobtype})
    return result[1]
    -- return exports.oxmysql:executeSync('SELECT information, tags, gallery FROM mdt WHERE cid= ? and type = ?', { cid, jobtype })
end

function GetIncidentName(id)
    -- Should also be a scalar
    local result = MySQL.query.await('SELECT title FROM `mdt_incidents` WHERE id = :id LIMIT 1', { id = id })
    return result[1]
    -- return exports.oxmysql:executeSync('SELECT title FROM `mdt_incidents` WHERE id = :id LIMIT 1', { id = id })
end

function GetConvictions(cids)
    return MySQL.query.await('SELECT * FROM `mdt_convictions` WHERE `cid` IN(?)', { cids })
    -- return exports.oxmysql:executeSync('SELECT * FROM `mdt_convictions` WHERE `cid` IN(?)', { cids })
end

function GetLicenseInfo(cid) -- CHECK: this looks like it used to be for esx and no longer in use
    local result = MySQL.query.await('SELECT * FROM `licenses` WHERE `cid` = ?', { cid })
    return result
    -- return exports.oxmysql:executeSync('SELECT * FROM `licenses` WHERE `cid`=:cid', { cid = cid })
end

function CreateUser(cid, tableName) -- CHECK: this looks like it is no longer in use
    AddLog("A user was created with the CID: "..cid)
    -- return exports.oxmysql:insert("INSERT INTO `"..dbname.."` (cid) VALUES (:cid)", { cid = cid })
    return MySQL.insert.await("INSERT INTO `"..tableName.."` (cid) VALUES (:cid)", { cid = cid })
end

function GetPlayerVehicles(cid)
    return DB?.GetPlayerVehicles(cid)
end

function GetBulletins(JobType)
    return MySQL.query.await('SELECT * FROM `mdt_bulletin` WHERE `jobtype` = ? LIMIT 10', { JobType })
    -- return exports.oxmysql:executeSync('SELECT * FROM `mdt_bulletin` WHERE `type`= ? LIMIT 10', { JobType })
end

function GetPlayerPropertiesByCitizenId(cid)
    return DB?.GetPlayerPropertiesByCitizenId(cid)
end

function GetPlayerDataByCitizenId(id)
    return DB?.GetPlayerDataByCitizenId(id)
end

function GetBoloStatus(plate)
    local result = MySQL.query.await("SELECT * FROM mdt_bolos where plate = @plate", {['@plate'] = plate})
    if result and result[1] then
        local title = result[1]['title']
        local boloId = result[1]['id']
        return true, title, boloId
    end
    return false
end

function GetOwnerName(cid) -- CHECK: looks like it's not used in the resource
    return DB?.GetOwnerName(cid)
end

function GetVehicleInformationByPlate(plate)
    local result = MySQL.query.await('SELECT * FROM mdt_vehicleinfo WHERE plate = @plate', {['@plate'] = plate})
    if result[1] then
        return result[1]
    else
        return false
    end
end

function GetPlayerApartmentByCitizenId(cid)
    return DB?.GetPlayerApartmentByCitizenId(cid)
end

function GetPlayerLicenses(citizenid)
    return DB?.GetPlayerLicenses(citizenid)
end

function ManageLicense(citizenid, type, status)
    DB?.ManageLicense(citizenid, type, status)
end

function UpdateAllLicenses(citizenid, incomingLicenses)
    DB?.UpdateAllLicenses(citizenid, incomingLicenses)
end

function SearchAllPlayersByData(query, jobType)
    return DB?.SearchAllPlayersByData(query, jobType)
end

function SearchPlayerIncidentByData(query, jobType)
    return DB?.SearchPlayerIncidentByData(query, jobType)
end

function SearchAllVehiclesByData(query)
    return DB?.SearchAllVehiclesByData(query)
end

function SearchVehicleDataByPlate(plate)
    return DB?.SearchVehicleDataByPlate(plate)
end

function GetVehicleWarrantStatusByPlate(plate)
    return DB?.GetVehicleWarrantStatusByPlate(plate)
end

function GetVehicleOwnerByPlate(plate)
    return DB?.GetVehicleOwnerByPlate(plate)
end
