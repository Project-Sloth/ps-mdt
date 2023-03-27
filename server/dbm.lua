-- Get CitizenIDs from Player License
function GetCitizenID(license)
    local result = DB?.GetCitizenID(license)
    if result == nil then print("Cannot find a CitizenID for License: "..license) end
    return result
end

-- (Start) Opening the MDT and sending data
function AddLog(text)
    --print(text)
    return MySQL.insert.await('INSERT INTO `mdt_logs` (`text`, `time`) VALUES (?,?)', {text, os.time() * 1000})
    -- return exports.oxmysql:execute('INSERT INTO `mdt_logs` (`text`, `time`) VALUES (:text, :time)', { text = text, time = os.time() * 1000 })
end

function GetNameFromId(cid)
    local result = DB?.GetNameFromId(cid)
    if result == nil then print("Cannot find a name for CID: "..cid) end
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

function GetPlayerProperties(cid)
    return DB?.GetPlayerProperties(cid)
end

function GetPlayerDataById(id)
    return DB?.GetPlayerDataById(id)
end

function GetBoloStatus(plate)
    local result = MySQL.scalar.await('SELECT id FROM `mdt_bolos` WHERE LOWER(`plate`)=:plate', { plate = string.lower(plate)})
    return result
    -- return exports.oxmysql:scalarSync('SELECT id FROM `mdt_bolos` WHERE LOWER(`plate`)=:plate', { plate = string.lower(plate)})
end

function GetOwnerName(cid)
    return DB?.GetOwnerName(cid)
end

function GetVehicleInformation(plate, cb)
    local result = MySQL.query.await('SELECT id, information FROM `mdt_vehicleinfo` WHERE plate=:plate', { plate = plate})
    cb(result)
end

function GetPlayerApartment(cid)
    return DB?.GetPlayerApartment(cid)
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