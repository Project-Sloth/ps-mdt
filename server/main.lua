local QBCore = exports['qb-core']:GetCoreObject()
local incidents = {}
local convictions = {}
local bolos = {}
local MugShots = {}
local activeUnits = {}
local impound = {}
local dispatchMessages = {}
local isDispatchRunning = false

local function GetActiveData(cid)
    local player = type(cid) == "string" and cid or tostring(cid)
    if player then
        return activeUnits[player] and true or false
    end
    return false
end

local function IsPoliceOrEms(job)
    for k, v in pairs(Config.PoliceJobs) do
           if job == k then
              return true
            end
         end
         
         for k, v in pairs(Config.AmbulanceJobs) do
           if job == k then
              return true
            end
         end
    return false
end

RegisterServerEvent("ps-mdt:dispatchStatus", function(bool)
    isDispatchRunning = bool
end)

if Config.UseWolfknightRadar == true then
    RegisterNetEvent("wk:onPlateScanned")
    AddEventHandler("wk:onPlateScanned", function(cam, plate, index)
        local src = source
        local player = Framework.GetPlayerByServerId(src)
        local vehicleOwner = GetVehicleOwnerByPlate(plate)
        local bolo, title, boloId = GetBoloStatus(plate)
        local warrant, owner, incidentId = GetVehicleWarrantStatusByPlate(plate)
        local driversLicense = Framework.GetPlayerLicensesByPlayer(player)?.driver

        if bolo == true then
            Framework.Notification(src, 'BOLO ID: '..boloId..' | Title: '..title..' | Registered Owner: '..vehicleOwner..' | Plate: '..plate, 'error', Config.WolfknightNotifyTime)
        end
        if warrant == true then
            Framework.Notification(src, 'WANTED - INCIDENT ID: '..incidentId..' | Registered Owner: '..owner..' | Plate: '..plate, 'error', Config.WolfknightNotifyTime)
        end

        if driversLicense == false and vehicleOwner then -- CHECK: this doesn't look true as it checks self driver license...
            Framework.Notification(src, 'NO DRIVERS LICENCE | Registered Owner: '..vehicleOwner..' | Plate: '..plate, 'error', Config.WolfknightNotifyTime)
        end


        if bolo or warrant or not driversLicense then
            TriggerClientEvent("wk:togglePlateLock", src, cam, true, 1)
        end
    end)
end

RegisterNetEvent("ps-mdt:server:OnPlayerUnload", function()
    --// Delete player from the MDT on logout
    local src = source
    local citizenId = Framework.GetPlayerCitizenIdByServerId(src)
    if GetActiveData(citizenId) then
        activeUnits[citizenId] = nil
    end
end)

AddEventHandler("playerDropped", function(reason)
    --// Delete player from the MDT on logout
    local src = source
    local player = Framework.GetPlayerByServerId(src)
    local citizenId = Framework.GetPlayerCitizenIdByPlayer(player) or Framework.GetPlayerCitizenIdByServerId(src)
    local time = os.date("%Y-%m-%d %H:%M:%S")
    local firstName = Framework.GetPlayerFirstNameByPlayer(player)
    local lastName = Framework.GetPlayerLastNameByPlayer(player)

    -- Auto clock out if the player is off duty
    if Framework.GetPlayerJobDutyByPlayer(player) then
        MySQL.query.await('UPDATE mdt_clocking SET clock_out_time = NOW(), total_time = TIMESTAMPDIFF(SECOND, clock_in_time, NOW()) WHERE user_id = @user_id ORDER BY id DESC LIMIT 1', {
            ['@user_id'] = citizenId
        })

        local result = MySQL.scalar.await('SELECT total_time FROM mdt_clocking WHERE user_id = @user_id', {
            ['@user_id'] = citizenId
        })
        if result then
            local time_formatted = format_time(tonumber(result))
            sendToDiscord(16753920, "MDT Clock-Out", 'Player: **' ..  firstName .. " ".. lastName .. '**\n\nJob: **' .. Framework.GetPlayerJobNameByPlayer(player) .. '**\n\nRank: **' .. Framework.GetPlayerJobGradeNameByPlayer(player) .. '**\n\nStatus: **Disconnected - Auto Clocked Out**\n Total time:' .. time_formatted, "ps-mdt | Made by Project Sloth")
        end
    end

    if citizenId ~= nil then
        if GetActiveData(citizenId) then
            activeUnits[citizenId] = nil
        end
    else
        local license = Framework.GetPlayerIdentifierByServerId(src, "license")
        local citizenids = GetCitizenIDByLicense(license)
        
        if type(citizenids) == "string" then
            if GetActiveData(citizenids) then
                activeUnits[citizenids] = nil
            end
        elseif type(citizenids) == "table" then
            for _, v in pairs(citizenids) do
                if GetActiveData(v.citizenid) then
                    activeUnits[v.citizenid] = nil
                end
            end
        end
    end
end)

RegisterNetEvent("ps-mdt:server:ToggleDuty", function()
    local src = source
    local player = Framework.GetPlayerByServerId(src)
    local jobDutyState = Framework.GetPlayerJobDutyByPlayer(player)

    if not jobDutyState then
        --// Remove from MDT
        local citizenId = Framework.GetPlayerCitizenIdByPlayer(player)
        if GetActiveData(citizenId) then
            activeUnits[citizenId] = nil
        end
    end
end)

RegisterCommand("mdtleaderboard", function(source, args)
    local player = Framework.GetPlayerByServerId(source)
    local playerJobName = Framework.GetPlayerJobNameByPlayer(player)

    if not IsPoliceOrEms(playerJobName) then
        Framework.Notification(source, "You don't have permission to use this command.", 'error')
        return
    end

    local result = MySQL.Sync.fetchAll('SELECT firstname, lastname, total_time FROM mdt_clocking ORDER BY total_time DESC')

    local leaderboard_message = '**MDT Leaderboard**\n\n'

    for i, record in ipairs(result) do
        local firstName = record.firstname:sub(1,1):upper()..record.firstname:sub(2)
        local lastName = record.lastname:sub(1,1):upper()..record.lastname:sub(2)
        local total_time = format_time(record.total_time)
    
        leaderboard_message = leaderboard_message .. i .. '. **' .. firstName .. ' ' .. lastName .. '** - ' .. total_time .. '\n'
    end

    sendToDiscord(16753920, "MDT Leaderboard", leaderboard_message, "ps-mdt | Made by Project Sloth")
    Framework.Notification(source, "MDT leaderboard sent to Discord!", 'success')
end, false)

RegisterNetEvent("ps-mdt:server:ClockSystem", function()
    local src = source
    local player = Framework.GetPlayerByServerId(src)
    local time = os.date("%Y-%m-%d %H:%M:%S")
    local firstName = Framework.GetPlayerFirstNameByPlayer(player)
    local lastName = Framework.GetPlayerLastNameByPlayer(player)
    if Framework.GetPlayerJobDutyByPlayer(player) then

        Framework.Notification(src, "You're clocked-in", 'success')
        MySQL.Async.insert('INSERT INTO mdt_clocking (user_id, firstname, lastname, clock_in_time) VALUES (:user_id, :firstname, :lastname, :clock_in_time) ON DUPLICATE KEY UPDATE user_id = :user_id, firstname = :firstname, lastname = :lastname, clock_in_time = :clock_in_time', {
            user_id = Framework.GetPlayerCitizenIdByPlayer(player),
            firstname = firstName,
            lastname = lastName,
            clock_in_time = time
        })
        sendToDiscord(65280, "MDT Clock-In", 'Player: **' ..  firstName .. " ".. lastName .. '**\n\nJob: **' .. Framework.GetPlayerJobNameByPlayer(player) .. '**\n\nRank: **' .. Framework.GetPlayerJobGradeNameByPlayer(player) .. '**\n\nStatus: **On Duty**', "ps-mdt | Made by Project Sloth")
    else
        Framework.Notification(src, "You're clocked-out", 'success')
        MySQL.query('UPDATE mdt_clocking SET clock_out_time = NOW(), total_time = TIMESTAMPDIFF(SECOND, clock_in_time, NOW()) WHERE user_id = @user_id ORDER BY id DESC LIMIT 1', {
            ['@user_id'] = Framework.GetPlayerCitizenIdByPlayer(player)
        })

        local result = MySQL.scalar.await('SELECT total_time FROM mdt_clocking WHERE user_id = @user_id', {
            ['@user_id'] = Framework.GetPlayerCitizenIdByPlayer(player)
        })
        if result then
            local time_formatted = format_time(tonumber(result))
            sendToDiscord(16711680, "MDT Clock-Out", 'Player: **' ..  firstName .. " ".. lastName .. '**\n\nJob: **' .. Framework.GetPlayerJobNameByPlayer(player) .. '**\n\nRank: **' .. Framework.GetPlayerJobGradeNameByPlayer(player) .. '**\n\nStatus: **Off Duty**\n Total time:' .. time_formatted, "ps-mdt | Made by Project Sloth")
        end
    end
end)

RegisterNetEvent('mdt:server:openMDT', function()
    local src = source
    local player = Framework.GetPlayerByServerId(src)
    local playerJobName = Framework.GetPlayerJobNameByPlayer(player)
    if not PermCheckByJobName(src, playerJobName) then return end
    local Radio = Player(src).state.radioChannel or 0

    local playerCitizenId = Framework.GetPlayerCitizenIdByPlayer(player)

    activeUnits[playerCitizenId] = {
        cid = playerCitizenId,
        callSign = Framework.GetPlayerCallSignByPlayer(player),
        firstName = Framework.GetPlayerFirstNameByPlayer(player),
        lastName = Framework.GetPlayerLastNameByPlayer(player),
        radio = Radio,
        unitType = playerJobName,
        duty = Framework.GetPlayerJobDutyByPlayer(player)
    }

    local JobType = GetJobType(playerJobName)
    local bulletin = GetBulletins(JobType)
    local calls = exports['ps-dispatch']:GetDispatchCalls()
    --TriggerClientEvent('mdt:client:dashboardbulletin', src, bulletin)
    TriggerClientEvent('mdt:client:open', src, bulletin, activeUnits, calls, playerCitizenId)
    --TriggerClientEvent('mdt:client:GetActiveUnits', src, activeUnits)
end)

Framework.CreateServerCallback('mdt:server:SearchProfile', function(source, cb, sentData)
    if not sentData then  return cb({}) end
    local src = source
    local player = Framework.GetPlayerByServerId(src)
    if player then
        local JobType = GetJobType(Framework.GetPlayerJobNameByPlayer(player))
        if JobType ~= nil then
            local people = SearchAllPlayersByData(sentData, JobType) or {}
            local citizenIds = {}
            local citizenIdIndexMap = {}
            if not next(people) then cb({}) return end

            for index, data in pairs(people) do
                people[index]['warrant'] = false
                people[index]['convictions'] = 0
                people[index]['licences'] = GetPlayerLicenses(data.citizenid)
                people[index]['pp'] = ProfPic(data.gender, data.pfp)
                citizenIds[#citizenIds+1] = data.citizenid
                citizenIdIndexMap[data.citizenid] = index
            end

            local convictions = GetConvictions(citizenIds)

            if next(convictions) then
                for _, conv in pairs(convictions) do
                    if conv.warrant == "1" then people[citizenIdIndexMap[conv.cid]].warrant = true end

                    local charges = json.decode(conv.charges)
                    people[citizenIdIndexMap[conv.cid]].convictions = people[citizenIdIndexMap[conv.cid]].convictions + #charges
                end
            end


            return cb(people)
        end
    end

    return cb({})
end)

Framework.CreateServerCallback("mdt:server:getWarrants", function(source, cb)
    local WarrantData = {}
    local data = MySQL.query.await("SELECT * FROM mdt_convictions", {})
    for _, value in pairs(data) do
        if value.warrant == "1" then
            WarrantData[#WarrantData+1] = {
                cid = value.cid,
                linkedincident = value.linkedincident,
                name = GetNameFromCitizenId(value.cid),
                time = value.time
            }
        end
    end
    cb(WarrantData)
end)

Framework.CreateServerCallback('mdt:server:OpenDashboard', function(source, cb)
    local player = Framework.GetPlayerByServerId(src)
    local playerJobName = Framework.GetPlayerJobNameByPlayer(player)
    if not PermCheckByJobName(source, playerJobName) then return end
    local JobType = GetJobType(playerJobName)
    local bulletin = GetBulletins(JobType)
    cb(bulletin)
end)

RegisterNetEvent('mdt:server:NewBulletin', function(title, info, time)
    local src = source
    local player = Framework.GetPlayerByServerId(src)
    local playerJobName = Framework.GetPlayerJobNameByPlayer(player)
    if not PermCheckByJobName(src, playerJobName) then return end
    local JobType = GetJobType(playerJobName)
    local playerName = Framework.GetPlayerFullNameByPlayer(player)
    local newBulletin = MySQL.insert.await('INSERT INTO `mdt_bulletin` (`title`, `desc`, `author`, `time`, `jobtype`) VALUES (:title, :desc, :author, :time, :jt)', {
        title = title,
        desc = info,
        author = playerName,
        time = tostring(time),
        jt = JobType
    })

    AddLog(("A new bulletin was added by %s with the title: %s!"):format(playerName, title))
    TriggerClientEvent('mdt:client:newBulletin', -1, src, {id = newBulletin, title = title, info = info, time = time, author = Framework.GetPlayerCitizenIdByPlayer(player)}, JobType)
end)

RegisterNetEvent('mdt:server:deleteBulletin', function(id, title)
    if not id then return false end
    local src = source
    local player = Framework.GetPlayerByServerId(src)
    local playerJobName = Framework.GetPlayerJobNameByPlayer(player)
    if not PermCheckByJobName(src, playerJobName) then return end
    -- local JobType = GetJobType(playerJobName)

    MySQL.query.await('DELETE FROM `mdt_bulletin` where id = ?', {id})
    AddLog("Bulletin with Title: "..title.." was deleted by " .. Framework.GetPlayerFullNameByPlayer(player) .. ".")
end)

Framework.CreateServerCallback('mdt:server:GetProfileData', function(source, cb, sentId)
    if not sentId then return cb({}) end

    local src = source
    local player = Framework.GetPlayerByServerId(src)
    local playerJobName = Framework.GetPlayerJobNameByPlayer(player)
    if not PermCheckByJobName(src, playerJobName) then return cb({}) end
    local JobType = GetJobType(playerJobName)
    local target = GetPlayerDataByCitizenId(sentId)

    if not target or not next(target) then return cb({}) end

    if type(target.job) == 'string' then target.job = json.decode(target.job) end
    if type(target.charinfo) == 'string' then target.charinfo = json.decode(target.charinfo) end
    if type(target.metadata) == 'string' then target.metadata = json.decode(target.metadata) end

    local licencesdata = target.metadata['licences'] or {
        ['driver'] = false,
        ['business'] = false,
        ['weapon'] = false,
        ['pilot'] = false
    }

    local job, grade = UnpackJobData(target.job)

    local apartmentData = GetPlayerApartmentByCitizenId(target.citizenid)

    local person = {
        cid = target.citizenid,
        firstname = target.charinfo.firstname,
        lastname = target.charinfo.lastname,
        job = job.label,
        grade = grade.name,
        apartment = apartmentData,
        pp = ProfPic(target.charinfo.gender),
        licences = licencesdata,
        dob = target.charinfo.birthdate,
        fingerprint = target.metadata.fingerprint,
        phone = target.charinfo.phone,
        mdtinfo = '',
        tags = {},
        vehicles = {},
        properties = {},
        gallery = {},
        isLimited = false
    }

    if Config.PoliceJobs[playerJobName] or Config.DojJobs[playerJobName] then
        local convictions = GetConvictions({person.cid})
        local incidents = {}
        person.convictions2 = {}
        local convCount = 1
        if next(convictions) then
            for _, conv in pairs(convictions) do
                if conv.warrant == "1" then person.warrant = true end
                
                -- Get the incident details
                local id = conv.linkedincident
                local incident = GetIncidentName(id)

                if incident then
                    incidents[#incidents + 1] = {
                        id = id,
                        title = incident.title,
                        time = conv.time
                    }
                end

                local charges = json.decode(conv.charges)
                for _, charge in pairs(charges) do
                    person.convictions2[convCount] = charge
                    convCount = convCount + 1
                end
            end
        end

        person.incidents = incidents

        local hash = {}
        person.convictions = {}

        for _,v in ipairs(person.convictions2) do
            if (not hash[v]) then
                person.convictions[#person.convictions+1] = v
                hash[v] = true
            end
        end

        local vehicles = GetPlayerVehicles(person.cid)

        if vehicles then
            person.vehicles = vehicles
        end
        local Coords = {}
        local Houses = {}
        local properties= GetPlayerPropertiesByCitizenId(person.cid)
        if properties and type(properties) == "table" then
            for _, v in pairs(properties) do
                Coords[#Coords+1] = {
                    coords = json.decode(v["coords"]),
                }
            end
            for index = 1, #Coords, 1 do
                Houses[#Houses+1] = {
                    label = properties[index]["label"],
                    coords = tostring(Coords[index]["coords"]["enter"]["x"]..",".. Coords[index]["coords"]["enter"]["y"].. ",".. Coords[index]["coords"]["enter"]["z"]),
                }
            end
        end
        person.properties = Houses
    end

    local mdtData = GetPersonInformation(sentId, JobType)
    if mdtData then
        person.mdtinfo = mdtData.information
        person.profilepic = mdtData.pfp
        person.tags = json.decode(mdtData.tags)
        person.gallery = json.decode(mdtData.gallery)
    end

    return cb(person)
end)

RegisterNetEvent("mdt:server:saveProfile", function(pfp, information, cid, fName, sName, tags, gallery, licenses)
    local src = source
    local player = Framework.GetPlayerByServerId(src)
    local playerJobName = Framework.GetPlayerJobNameByPlayer(player)
    UpdateAllLicenses(cid, licenses) -- CHECK: this is not secure at all!
    if player then
        local JobType = GetJobType(playerJobName)
        if JobType == 'doj' then JobType = 'police' end -- CHECK: are you sure about this?

        MySQL.Async.insert('INSERT INTO mdt_data (cid, information, pfp, jobtype, tags, gallery) VALUES (:cid, :information, :pfp, :jobtype, :tags, :gallery) ON DUPLICATE KEY UPDATE cid = :cid, information = :information, pfp = :pfp, jobtype = :jobtype, tags = :tags, gallery = :gallery', {
            cid = cid,
            information = information,
            pfp = pfp,
            jobtype = JobType,
            tags = json.encode(tags),
            gallery = json.encode(gallery),
        }, function()
        end)
    end
end)

-- Mugshotd
RegisterNetEvent('cqc-mugshot:server:triggerSuspect', function(suspect)
    TriggerClientEvent('cqc-mugshot:client:trigger', suspect, suspect)
end)

RegisterNetEvent('psmdt-mugshot:server:MDTupload', function(citizenid, MugShotURLs)
    MugShots[citizenid] = MugShotURLs
    local cid = citizenid
    MySQL.Async.insert('INSERT INTO mdt_data (cid, pfp, gallery, tags) VALUES (:cid, :pfp, :gallery, :tags) ON DUPLICATE KEY UPDATE cid = :cid,  pfp = :pfp, tags = :tags, gallery = :gallery', { -- CHECK: hello SQL injection!
        cid = cid,
        pfp = MugShotURLs[1],
        tags = json.encode(tags),
        gallery = json.encode(MugShotURLs),
    })
end)

RegisterNetEvent("mdt:server:updateLicense", function(cid, type, status)
    local src = source
    local player = Framework.GetPlayerByServerId(src)
    if player then
        local playerJobName = Framework.GetPlayerJobNameByPlayer(player)
        if GetJobType(playerJobName) == 'police' then
            ManageLicense(cid, type, status)
        end
    end
end)

-- Incidents

RegisterNetEvent('mdt:server:getAllIncidents', function()
    local src = source
    local player = Framework.GetPlayerByServerId(src)
    if player then
        local playerJobName = Framework.GetPlayerJobNameByPlayer(player)
        local JobType = GetJobType(playerJobName)
        if JobType == 'police' or JobType == 'doj' then
            local matches = MySQL.query.await("SELECT * FROM `mdt_incidents` ORDER BY `id` DESC LIMIT 30", {})

            TriggerClientEvent('mdt:client:getAllIncidents', src, matches)
        end
    end
end)

RegisterNetEvent('mdt:server:searchIncidents', function(query)
    if query then
        local src = source
        local player = Framework.GetPlayerByServerId(src)
        if player then
            local playerJobName = Framework.GetPlayerJobNameByPlayer(player)
            local JobType = GetJobType(playerJobName)
            if JobType == 'police' or JobType == 'doj' then
                local matches = MySQL.query.await("SELECT * FROM `mdt_incidents` WHERE `id` LIKE :query OR LOWER(`title`) LIKE :query OR LOWER(`author`) LIKE :query OR LOWER(`details`) LIKE :query OR LOWER(`tags`) LIKE :query OR LOWER(`officersinvolved`) LIKE :query OR LOWER(`civsinvolved`) LIKE :query OR LOWER(`author`) LIKE :query ORDER BY `id` DESC LIMIT 50", {
                    query = string.lower('%'..query..'%') -- % wildcard, needed to search for all alike results
                })

                TriggerClientEvent('mdt:client:getIncidents', src, matches)
            end
        end
    end
end)

RegisterNetEvent('mdt:server:getIncidentData', function(sentId)
    if sentId then
        local src = source
        local player = Framework.GetPlayerByServerId(src)
        if player then
            local playerJobName = Framework.GetPlayerJobNameByPlayer(player)
            local JobType = GetJobType(playerJobName)
            if JobType == 'police' or JobType == 'doj' then
                local matches = MySQL.query.await("SELECT * FROM `mdt_incidents` WHERE `id` = :id", {
                    id = sentId
                })
                local data = matches[1]
                data['tags'] = json.decode(data['tags'])
                data['officersinvolved'] = json.decode(data['officersinvolved'])
                data['civsinvolved'] = json.decode(data['civsinvolved'])
                data['evidence'] = json.decode(data['evidence'])


                local convictions = MySQL.query.await("SELECT * FROM `mdt_convictions` WHERE `linkedincident` = :id", {
                    id = sentId
                })
                if convictions ~= nil then
                    for i=1, #convictions do
                        local res = GetNameFromCitizenId(convictions[i]['cid'])
                        if res ~= nil then
                            convictions[i]['name'] = res
                        else
                            convictions[i]['name'] = "Unknown"
                        end
                        convictions[i]['charges'] = json.decode(convictions[i]['charges'])
                    end
                end
                TriggerClientEvent('mdt:client:getIncidentData', src, data, convictions)
            end
        end
    end
end)

RegisterNetEvent('mdt:server:getAllBolos', function()
    local src = source
    local player = Framework.GetPlayerByServerId(src)
    local playerJobName = Framework.GetPlayerJobNameByPlayer(player)
    local JobType = GetJobType(playerJobName)
    if JobType == 'police' or JobType == 'ambulance' then
        local matches = MySQL.query.await("SELECT * FROM `mdt_bolos` WHERE jobtype = :jobtype", {jobtype = JobType})
        TriggerClientEvent('mdt:client:getAllBolos', src, matches)
    end
end)

RegisterNetEvent('mdt:server:searchBolos', function(sentSearch)
    if sentSearch then
        local src = source
        local player = Framework.GetPlayerByServerId(src)
        local playerJobName = Framework.GetPlayerJobNameByPlayer(player)
        local JobType = GetJobType(playerJobName)
        if JobType == 'police' or JobType == 'ambulance' then
            local matches = MySQL.query.await("SELECT * FROM `mdt_bolos` WHERE `id` LIKE :query OR LOWER(`title`) LIKE :query OR `plate` LIKE :query OR LOWER(`owner`) LIKE :query OR LOWER(`individual`) LIKE :query OR LOWER(`detail`) LIKE :query OR LOWER(`officersinvolved`) LIKE :query OR LOWER(`tags`) LIKE :query OR LOWER(`author`) LIKE :query AND jobtype = :jobtype", {
                query = string.lower('%'..sentSearch..'%'), -- % wildcard, needed to search for all alike results
                jobtype = JobType
            })
            TriggerClientEvent('mdt:client:getBolos', src, matches)
        end
    end
end)

RegisterNetEvent('mdt:server:getBoloData', function(sentId)
    if sentId then
        local src = source
        local player = Framework.GetPlayerByServerId(src)
        local playerJobName = Framework.GetPlayerJobNameByPlayer(player)
        local JobType = GetJobType(playerJobName)
        if JobType == 'police' or JobType == 'ambulance' then
            local matches = MySQL.query.await("SELECT * FROM `mdt_bolos` WHERE `id` = :id AND jobtype = :jobtype LIMIT 1", {
                id = sentId,
                jobtype = JobType
            })

            local data = matches[1]
            data['tags'] = json.decode(data['tags'])
            data['officersinvolved'] = json.decode(data['officersinvolved'])
            data['gallery'] = json.decode(data['gallery'])
            TriggerClientEvent('mdt:client:getBoloData', src, data)
        end
    end
end)

RegisterNetEvent('mdt:server:newBolo', function(existing, id, title, plate, owner, individual, detail, tags, gallery, officersinvolved, time)
    if id then
        local src = source
        local player = Framework.GetPlayerByServerId(src)
        local playerJobName = Framework.GetPlayerJobNameByPlayer(player)
        local JobType = GetJobType(playerJobName)
        if JobType == 'police' or JobType == 'ambulance' then
            local fullname = Framework.GetPlayerFullNameByPlayer(player)

            local function InsertBolo()
                MySQL.insert('INSERT INTO `mdt_bolos` (`title`, `author`, `plate`, `owner`, `individual`, `detail`, `tags`, `gallery`, `officersinvolved`, `time`, `jobtype`) VALUES (:title, :author, :plate, :owner, :individual, :detail, :tags, :gallery, :officersinvolved, :time, :jobtype)', {
                    title = title,
                    author = fullname,
                    plate = plate,
                    owner = owner,
                    individual = individual,
                    detail = detail,
                    tags = json.encode(tags),
                    gallery = json.encode(gallery),
                    officersinvolved = json.encode(officersinvolved),
                    time = tostring(time),
                    jobtype = JobType
                }, function(r)
                    if r then
                        TriggerClientEvent('mdt:client:boloComplete', src, r)
                        TriggerEvent('mdt:server:AddLog', "A new BOLO was created by "..fullname.." with the title ("..title..") and ID ("..id..")")
                    end
                end)
            end

            local function UpdateBolo()
                MySQL.update("UPDATE mdt_bolos SET `title`=:title, plate=:plate, owner=:owner, individual=:individual, detail=:detail, tags=:tags, gallery=:gallery, officersinvolved=:officersinvolved WHERE `id`=:id AND jobtype = :jobtype LIMIT 1", {
                    title = title,
                    plate = plate,
                    owner = owner,
                    individual = individual,
                    detail = detail,
                    tags = json.encode(tags),
                    gallery = json.encode(gallery),
                    officersinvolved = json.encode(officersinvolved),
                    id = id,
                    jobtype = JobType
                }, function(r)
                    if r then
                        TriggerClientEvent('mdt:client:boloComplete', src, id)
                        TriggerEvent('mdt:server:AddLog', "A BOLO was updated by "..fullname.." with the title ("..title..") and ID ("..id..")")
                    end
                end)
            end

            if existing then
                UpdateBolo()
            elseif not existing then
                InsertBolo()
            end
        end
    end
end)

RegisterNetEvent('mdt:server:deleteWeapons', function(id)
    if id then
        local src = source
        local player = Framework.GetPlayerByServerId(src)
        local playerJobName = Framework.GetPlayerJobNameByPlayer(player)
        local playerJobGradeLevel = Framework.GetPlayerJobGradeLevelByPlayer(player)
        if Config.LogPerms[playerJobName] then
            if Config.LogPerms[playerJobName][playerJobGradeLevel] then
                local fullName = Framework.GetPlayerFullNameByPlayer(player)
                MySQL.update("DELETE FROM `mdt_weaponinfo` WHERE id=:id", { id = id })
                TriggerEvent('mdt:server:AddLog', "A Weapon Info was deleted by "..fullName.." with the ID ("..id..")")
            else
                local fullname = Framework.GetPlayerFullNameByPlayer(player)
                Framework.Notification(src, 'No Permissions to do that!', 'error')
                TriggerEvent('mdt:server:AddLog', fullname.." tried to delete a Weapon Info with the ID ("..id..")")
            end
        end
    end
end)

RegisterNetEvent('mdt:server:deleteReports', function(id)
    if id then
        local src = source
        local player = Framework.GetPlayerByServerId(src)
        local playerJobName = Framework.GetPlayerJobNameByPlayer(player)
        local playerJobGradeLevel = Framework.GetPlayerJobGradeLevelByPlayer(player)
        if Config.LogPerms[playerJobName] then
            if Config.LogPerms[playerJobName][playerJobGradeLevel] then
                local fullName = Framework.GetPlayerFullNameByPlayer(player)
                MySQL.update("DELETE FROM `mdt_reports` WHERE id=:id", { id = id })
                TriggerEvent('mdt:server:AddLog', "A Report was deleted by "..fullName.." with the ID ("..id..")")
            else
                local fullname = Framework.GetPlayerFullNameByPlayer(player)
                Framework.Notification(src, 'No Permissions to do that!', 'error')
                TriggerEvent('mdt:server:AddLog', fullname.." tried to delete a Report with the ID ("..id..")")
            end
        end
    end
end)

RegisterNetEvent('mdt:server:deleteIncidents', function(id)
    local src = source
    local player = Framework.GetPlayerByServerId(src)
    local playerJobName = Framework.GetPlayerJobNameByPlayer(player)
    local playerJobGradeLevel = Framework.GetPlayerJobGradeLevelByPlayer(player)
    if Config.LogPerms[playerJobName] then
        if Config.LogPerms[playerJobName][playerJobGradeLevel] then
            local fullName = Framework.GetPlayerFullNameByPlayer(player)
            MySQL.update("DELETE FROM `mdt_convictions` WHERE `linkedincident` = :id", {id = id})
            MySQL.update("UPDATE `mdt_convictions` SET `warrant` = '0' WHERE `linkedincident` = :id", {id = id}) -- Delete any outstanding warrants from incidents
            MySQL.update("DELETE FROM `mdt_incidents` WHERE id=:id", { id = id }, function(rowsChanged)
                if rowsChanged > 0 then
                    TriggerEvent('mdt:server:AddLog', "A Incident was deleted by "..fullName.." with the ID ("..id..")")
                end
            end)
        else
            local fullname = Framework.GetPlayerFullNameByPlayer(player)
            Framework.Notification(src, 'No Permissions to do that!', 'error')
            TriggerEvent('mdt:server:AddLog', fullname.." tried to delete an Incident with the ID ("..id..")")
        end
    end
end)

RegisterNetEvent('mdt:server:deleteBolo', function(id)
    if id then
        local src = source
        local player = Framework.GetPlayerByServerId(src)
        local playerJobName = Framework.GetPlayerJobNameByPlayer(player)
        local JobType = GetJobType(playerJobName)
        if JobType == 'police' then
            local fullname = Framework.GetPlayerFullNameByPlayer(player)
            MySQL.update("DELETE FROM `mdt_bolos` WHERE id=:id", { id = id, jobtype = JobType })
            TriggerEvent('mdt:server:AddLog', "A BOLO was deleted by "..fullname.." with the ID ("..id..")")
        end
    end
end)

RegisterNetEvent('mdt:server:deleteICU', function(id)
    if id then
        local src = source
        local player = Framework.GetPlayerByServerId(src)
        local playerJobName = Framework.GetPlayerJobNameByPlayer(player)
        local JobType = GetJobType(playerJobName)
        if JobType == 'ambulance' then
            local fullname = Framework.GetPlayerFullNameByPlayer(player)
            MySQL.update("DELETE FROM `mdt_bolos` WHERE id=:id", { id = id, jobtype = JobType })
            TriggerEvent('mdt:server:AddLog', "A ICU Check-in was deleted by "..fullname.." with the ID ("..id..")")
        end
    end
end)

RegisterNetEvent('mdt:server:incidentSearchPerson', function(query)
    if query then
        local src = source
        local player = Framework.GetPlayerByServerId(src)
        if player then
            local playerJobName = Framework.GetPlayerJobNameByPlayer(player)
            local JobType = GetJobType(playerJobName)
            if JobType == 'police' or JobType == 'doj' or JobType == 'ambulance' then
                local function ProfPic(gender, profilepic) -- CHECK: this should be removed since it's the same as the one in utils.lua
                    if profilepic then return profilepic end
                    if gender == "f" then return "img/female.png" end
                    return "img/male.png"
                end

                local result = SearchPlayerIncidentByData(query, JobType)
                
                local data = {}
                for i=1, #result do
                    local charinfo = json.decode(result[i].charinfo)
                    local metadata = json.decode(result[i].metadata)
                    data[i] = {
                        id = result[i].citizenid,
                        firstname = charinfo.firstname,
                        lastname = charinfo.lastname,
                        profilepic = ProfPic(charinfo.gender, result[i].pfp),
                        callsign = metadata.callsign
                    }
                end
                TriggerClientEvent('mdt:client:incidentSearchPerson', src, data)
            end
        end
    end
end)

RegisterNetEvent('mdt:server:getAllReports', function()
    local src = source
    local player = Framework.GetPlayerByServerId(src)
    if player then
        local playerJobName = Framework.GetPlayerJobNameByPlayer(player)
        local JobType = GetJobType(playerJobName)
        if JobType == 'police' or JobType == 'doj' or JobType == 'ambulance' then
            if JobType == 'doj' then JobType = 'police' end
            local matches = MySQL.query.await("SELECT * FROM `mdt_reports` WHERE jobtype = :jobtype ORDER BY `id` DESC LIMIT 30", {
                jobtype = JobType
            })
            TriggerClientEvent('mdt:client:getAllReports', src, matches)
        end
    end
end)

RegisterNetEvent('mdt:server:getReportData', function(sentId)
    if sentId then
        local src = source
        local player = Framework.GetPlayerByServerId(src)
        if player then
            local playerJobName = Framework.GetPlayerJobNameByPlayer(player)
            local JobType = GetJobType(playerJobName)
            if JobType == 'police' or JobType == 'doj' or JobType == 'ambulance' then
                if JobType == 'doj' then JobType = 'police' end
                local matches = MySQL.query.await("SELECT * FROM `mdt_reports` WHERE `id` = :id AND `jobtype` = :jobtype LIMIT 1", {
                    id = sentId,
                    jobtype = JobType
                })
                local data = matches[1]
                data['tags'] = json.decode(data['tags'])
                data['officersinvolved'] = json.decode(data['officersinvolved'])
                data['civsinvolved'] = json.decode(data['civsinvolved'])
                data['gallery'] = json.decode(data['gallery'])
                TriggerClientEvent('mdt:client:getReportData', src, data)
            end
        end
    end
end)

RegisterNetEvent('mdt:server:searchReports', function(sentSearch)
    if sentSearch then
        local src = source
        local player = Framework.GetPlayerByServerId(src)
        if player then
            local playerJobName = Framework.GetPlayerJobNameByPlayer(player)
            local JobType = GetJobType(playerJobName)
            if JobType == 'police' or JobType == 'doj' or JobType == 'ambulance' then
                if JobType == 'doj' then JobType = 'police' end
                local matches = MySQL.query.await("SELECT * FROM `mdt_reports` WHERE `id` LIKE :query OR LOWER(`author`) LIKE :query OR LOWER(`title`) LIKE :query OR LOWER(`type`) LIKE :query OR LOWER(`details`) LIKE :query OR LOWER(`tags`) LIKE :query AND `jobtype` = :jobtype ORDER BY `id` DESC LIMIT 50", {
                    query = string.lower('%'..sentSearch..'%'), -- % wildcard, needed to search for all alike results
                    jobtype = JobType
                })

                TriggerClientEvent('mdt:client:getAllReports', src, matches)
            end
        end
    end
end)

RegisterNetEvent('mdt:server:newReport', function(existing, id, title, reporttype, details, tags, gallery, officers, civilians, time)
    if id then
        local src = source
        local player = Framework.GetPlayerByServerId(src)
        if player then
            local playerJobName = Framework.GetPlayerJobNameByPlayer(player)
            local JobType = GetJobType(playerJobName)
            if JobType ~= nil then
                local fullname = Framework.GetPlayerFullNameByPlayer(player)
                local function InsertReport()
                    MySQL.insert('INSERT INTO `mdt_reports` (`title`, `author`, `type`, `details`, `tags`, `gallery`, `officersinvolved`, `civsinvolved`, `time`, `jobtype`) VALUES (:title, :author, :type, :details, :tags, :gallery, :officersinvolved, :civsinvolved, :time, :jobtype)', {
                        title = title,
                        author = fullname,
                        type = reporttype,
                        details = details,
                        tags = json.encode(tags),
                        gallery = json.encode(gallery),
                        officersinvolved = json.encode(officers),
                        civsinvolved = json.encode(civilians),
                        time = tostring(time),
                        jobtype = JobType,
                    }, function(r)
                        if r then
                            TriggerClientEvent('mdt:client:reportComplete', src, r)
                            TriggerEvent('mdt:server:AddLog', "A new report was created by "..fullname.." with the title ("..title..") and ID ("..id..")")
                        end
                    end)
                end

                local function UpdateReport()
                    MySQL.update("UPDATE `mdt_reports` SET `title` = :title, type = :type, details = :details, tags = :tags, gallery = :gallery, officersinvolved = :officersinvolved, civsinvolved = :civsinvolved, jobtype = :jobtype WHERE `id` = :id LIMIT 1", {
                        title = title,
                        type = reporttype,
                        details = details,
                        tags = json.encode(tags),
                        gallery = json.encode(gallery),
                        officersinvolved = json.encode(officers),
                        civsinvolved = json.encode(civilians),
                        jobtype = JobType,
                        id = id,
                    }, function(affectedRows)
                        if affectedRows > 0 then
                            TriggerClientEvent('mdt:client:reportComplete', src, id)
                            TriggerEvent('mdt:server:AddLog', "A report was updated by "..fullname.." with the title ("..title..") and ID ("..id..")")
                        end
                    end)
                end

                if existing then
                    UpdateReport()
                elseif not existing then
                    InsertReport()
                end
            end
        end
    end
end)

Framework.CreateServerCallback('mdt:server:SearchVehicles', function(source, cb, sentData)
    if not sentData then  return cb({}) end
    local src = source
    local player = Framework.GetPlayerByServerId(src)
    local playerJobName = Framework.GetPlayerJobNameByPlayer(player)
    if not PermCheckByJobName(source, playerJobName) then return cb({}) end

    if player then
        local JobType = GetJobType(playerJobName)
        if JobType == 'police' or JobType == 'doj' then
            local vehicles = SearchAllVehiclesByData(sentData)

            if not next(vehicles) then cb({}) return end

            for _, value in ipairs(vehicles) do
                if value.state == 0 then
                    value.state = "Out"
                elseif value.state == 1 then
                    value.state = "Garaged"
                elseif value.state == 2 then
                    value.state = "Impounded"
                end

                value.bolo = false
                local boloResult = GetBoloStatus(value.plate)
                if boloResult then
                    value.bolo = true
                end

                value.code = false
                value.stolen = false
                value.image = "img/not-found.webp"
                local info = GetVehicleInformationByPlate(value.plate)
                if info then
                    value.code = info['code5']
                    value.stolen = info['stolen']
                    value.image = info['image']
                end

                local ownerResult = json.decode(value.charinfo)

                value.owner = ownerResult['firstname'] .. " " .. ownerResult['lastname']
            end
            return cb(vehicles)
        end

        return cb({})
    end

end)

RegisterNetEvent('mdt:server:getVehicleData', function(plate)
    if plate then
        local src = source
        local player = Framework.GetPlayerByServerId(src)
        if player then
            local playerJobName = Framework.GetPlayerJobNameByPlayer(player)
            local JobType = GetJobType(playerJobName)
            if JobType == 'police' or JobType == 'doj' then
                local vehicle = SearchVehicleDataByPlate(plate)
                if vehicle and vehicle[1] then
                    vehicle[1]['impound'] = false
                    if vehicle[1].state == 2 then
                        vehicle[1]['impound'] = true
                    end

                    vehicle[1]['bolo'] = GetBoloStatus(vehicle[1]['plate'])
                    vehicle[1]['information'] = ""

                    vehicle[1]['name'] = "Unknown Person"

                    local ownerResult = json.decode(vehicle[1].charinfo)
                    vehicle[1]['name'] = ownerResult['firstname'] .. " " .. ownerResult['lastname']

                    local color1 = json.decode(vehicle[1].mods)
                    vehicle[1]['color1'] = color1['color1']

                    vehicle[1]['dbid'] = 0

                    local info = GetVehicleInformationByPlate(vehicle[1]['plate'])
                    if info then
                        vehicle[1]['information'] = info['information']
                        vehicle[1]['dbid'] = info['id']
                        vehicle[1]['points'] = info['points']
                        vehicle[1]['image'] = info['image']
                        vehicle[1]['code'] = info['code5']
                        vehicle[1]['stolen'] = info['stolen']
                    end

                    if vehicle[1]['image'] == nil then vehicle[1]['image'] = "img/not-found.webp" end
                end

                TriggerClientEvent('mdt:client:getVehicleData', src, vehicle)
            end
        end
    end
end)

RegisterNetEvent('mdt:server:saveVehicleInfo', function(dbid, plate, imageurl, notes, stolen, code5, impoundInfo, points) -- TODO: refactor this to be compatible with all frameworks such as esx...I cbf now
    if plate then
        local src = source
        local player = Framework.GetPlayerByServerId(src)
        if player then
            local playerJobName = Framework.GetPlayerJobNameByPlayer(player)
            if GetJobType(playerJobName) == 'police' then
                if dbid == nil then dbid = 0 end
                local fullname = Framework.GetPlayerFullNameByPlayer(player)
                TriggerEvent('mdt:server:AddLog', "A vehicle with the plate ("..plate..") has a new image ("..imageurl..") edited by "..fullname)
                if tonumber(dbid) == 0 then
                    MySQL.insert('INSERT INTO `mdt_vehicleinfo` (`plate`, `information`, `image`, `code5`, `stolen`, `points`) VALUES (:plate, :information, :image, :code5, :stolen, :points)', { plate = TrimString(plate), information = notes, image = imageurl, code5 = code5, stolen = stolen, points = tonumber(points) }, function(infoResult)
                        if infoResult then
                            TriggerClientEvent('mdt:client:updateVehicleDbId', src, infoResult)
                            TriggerEvent('mdt:server:AddLog', "A vehicle with the plate ("..plate..") was added to the vehicle information database by "..fullname)
                        end
                    end)
                elseif tonumber(dbid) > 0 then
                    MySQL.update("UPDATE mdt_vehicleinfo SET `information`= :information, `image`= :image, `code5`= :code5, `stolen`= :stolen, `points`= :points WHERE `plate`= :plate LIMIT 1", { plate = TrimString(plate), information = notes, image = imageurl, code5 = code5, stolen = stolen, points = tonumber(points) })
                end

                if impoundInfo.impoundChanged then
                    local vehicle = MySQL.single.await("SELECT p.id, p.plate, i.vehicleid AS impoundid FROM `player_vehicles` p LEFT JOIN `mdt_impound` i ON i.vehicleid = p.id WHERE plate=:plate", { plate = TrimString(plate) })
                    if impoundInfo.impoundActive then
                        local plate, linkedreport, fee, time = impoundInfo['plate'], impoundInfo['linkedreport'], impoundInfo['fee'], impoundInfo['time']
                        if (plate and linkedreport and fee and time) then
                            if vehicle.impoundid == nil then
                                -- This section is copy pasted from request impound and needs some attention.
                                -- sentVehicle doesnt exist.
                                -- data is defined twice
                                -- INSERT INTO will not work if it exists already (which it will)
                                local data = vehicle
                                MySQL.insert('INSERT INTO `mdt_impound` (`vehicleid`, `linkedreport`, `fee`, `time`) VALUES (:vehicleid, :linkedreport, :fee, :time)', {
                                    vehicleid = data['id'],
                                    linkedreport = linkedreport,
                                    fee = fee,
                                    time = os.time() + (time * 60)
                                }, function(res)
                                    
                                    local data = {
                                        vehicleid = data['id'],
                                        plate = plate,
                                        beingcollected = 0,
                                        vehicle = sentVehicle,
                                        officer = Framework.GetPlayerFullNameByPlayer(player),
                                        number = Framework.GetPlayerPhoneNumberByPlayer(player),
                                        time = os.time() * 1000,
                                        src = src,
                                    }
                                    local vehicle = NetworkGetEntityFromNetworkId(sentVehicle)
                                    FreezeEntityPosition(vehicle, true)
                                    impound[#impound+1] = data

                                    TriggerClientEvent("police:client:ImpoundVehicle", src, true, fee)
                                end)
                                -- Read above comment
                            end
                        end
                    else
                        if vehicle.impoundid ~= nil then
                            local data = vehicle
                            local result = MySQL.single.await("SELECT id, vehicle, fuel, engine, body FROM `player_vehicles` WHERE plate=:plate LIMIT 1", { plate = TrimString(plate)})
                            if result then
                                local data = result
                                MySQL.update("DELETE FROM `mdt_impound` WHERE vehicleid=:vehicleid", { vehicleid = data['id'] })

                                result.currentSelection = impoundInfo.CurrentSelection
                                result.plate = plate
                                TriggerClientEvent('ps-mdt:client:TakeOutImpound', src, result)
                            end

                        end
                    end
                end
            end
        end
    end
end)

RegisterNetEvent('mdt:server:searchCalls', function(calls)
    local src = source
    local player = Framework.GetPlayerByServerId(src)
    local playerJobName = Framework.GetPlayerJobNameByPlayer(player)
    local JobType = GetJobType(playerJobName)
    if JobType == 'police' then
        local calls = exports['ps-dispatch']:GetDispatchCalls()
        TriggerClientEvent('mdt:client:getCalls', src, calls)
    end
end)

Framework.CreateServerCallback('mdt:server:SearchWeapons', function(source, cb, sentData)
    if not sentData then  return cb({}) end
    local player = Framework.GetPlayerByServerId(source)
    local playerJobName = Framework.GetPlayerJobNameByPlayer(player)
    if not PermCheckByJobName(source, playerJobName) then return cb({}) end
    
    if player then
        local JobType = GetJobType(playerJobName)
        if JobType == 'police' or JobType == 'doj' then
            local matches = MySQL.query.await('SELECT * FROM mdt_weaponinfo WHERE LOWER(`serial`) LIKE :query OR LOWER(`weapModel`) LIKE :query OR LOWER(`owner`) LIKE :query LIMIT 25', {
                query = string.lower('%'..sentData..'%')
            })
            cb(matches)
        end
    end
end)

RegisterNetEvent('mdt:server:saveWeaponInfo', function(serial, imageurl, notes, owner, weapClass, weapModel)
    if serial then
        local player = Framework.GetPlayerByServerId(source)
        local playerJobName = Framework.GetPlayerJobNameByPlayer(player)
        if not PermCheckByJobName(source, playerJobName) then return cb({}) end
        
        if player then
            local JobType = GetJobType(playerJobName)
            if JobType == 'police' or JobType == 'doj' then
                local fullname = Framework.GetPlayerFullNameByPlayer(player)
                if imageurl == nil then imageurl = 'img/not-found.webp' end
                --AddLog event?
                local result = false
                result = MySQL.Async.insert('INSERT INTO mdt_weaponinfo (serial, owner, information, weapClass, weapModel, image) VALUES (:serial, :owner, :notes, :weapClass, :weapModel, :imageurl) ON DUPLICATE KEY UPDATE owner = :owner, information = :notes, weapClass = :weapClass, weapModel = :weapModel, image = :imageurl', {
                    ['serial'] = serial,
                    ['owner'] = owner,
                    ['notes'] = notes,
                    ['weapClass'] = weapClass,
                    ['weapModel'] = weapModel,
                    ['imageurl'] = imageurl,
                })

                if result then
                    TriggerEvent('mdt:server:AddLog', "A weapon with the serial number ("..serial..") was added to the weapon information database by "..fullname)
                else
                    TriggerEvent('mdt:server:AddLog', "A weapon with the serial number ("..serial..") failed to be added to the weapon information database by "..fullname)
                end
            end
        end
    end
end)

function CreateWeaponInfo(serial, imageurl, notes, owner, weapClass, weapModel)

    local results = MySQL.query.await('SELECT * FROM mdt_weaponinfo WHERE serial = ?', { serial })
    if results[1] then
        return
    end

    if serial == nil then return end
    if imageurl == nil then imageurl = 'img/not-found.webp' end

    MySQL.Async.insert('INSERT INTO mdt_weaponinfo (serial, owner, information, weapClass, weapModel, image) VALUES (:serial, :owner, :notes, :weapClass, :weapModel, :imageurl) ON DUPLICATE KEY UPDATE owner = :owner, information = :notes, weapClass = :weapClass, weapModel = :weapModel, image = :imageurl', {
        ['serial'] = serial,
        ['owner'] = owner,
        ['notes'] = notes,
        ['weapClass'] = weapClass,
        ['weapModel'] = weapModel,
        ['imageurl'] = imageurl,
    })
end

exports('CreateWeaponInfo', CreateWeaponInfo)

RegisterNetEvent('mdt:server:getWeaponData', function(serial)
    if serial then
        local player = Framework.GetPlayerByServerId(source)
        local playerJobName = Framework.GetPlayerJobNameByPlayer(player)
        if player then
            local JobType = GetJobType(playerJobName)
            if JobType == 'police' or JobType == 'doj' then
                local results = MySQL.query.await('SELECT * FROM mdt_weaponinfo WHERE serial = ?', { serial })
                TriggerClientEvent('mdt:client:getWeaponData', source, results)
            end
        end
    end
end)

RegisterNetEvent('mdt:server:getAllLogs', function()
    local src = source
    local player = Framework.GetPlayerByServerId(src)
    if player then
        local playerJobName = Framework.GetPlayerJobNameByPlayer(player)
        local playerJobGradeLevel = Framework.GetPlayerJobGradeLevelByPlayer(player)
        if Config.LogPerms[playerJobName] then
            if Config.LogPerms[playerJobName][playerJobGradeLevel] then

                local JobType = GetJobType(playerJobName)
                local infoResult = MySQL.query.await('SELECT * FROM mdt_logs WHERE `jobtype` = :jobtype ORDER BY `id` DESC LIMIT 250', {jobtype = JobType})

                TriggerLatentClientEvent('mdt:client:getAllLogs', src, 30000, infoResult)
            end
        end
    end
end)

-- Penal Code

local function IsCidFelon(sentCid, cb)
    if sentCid then
        local convictions = MySQL.query.await('SELECT charges FROM mdt_convictions WHERE cid=:cid', { cid = sentCid })
        local Charges = {}
        for i=1, #convictions do
            local currCharges = json.decode(convictions[i]['charges'])
            for x=1, #currCharges do
                Charges[#Charges+1] = currCharges[x]
            end
        end
        local PenalCode = Config.PenalCode
        for i=1, #Charges do
            for p=1, #PenalCode do
                for x=1, #PenalCode[p] do
                    if PenalCode[p][x]['title'] == Charges[i] then
                        if PenalCode[p][x]['class'] == 'Felony' then
                            cb(true)
                            return
                        end
                        break
                    end
                end
            end
        end
        cb(false)
    end
end

exports('IsCidFelon', IsCidFelon) -- exports['erp_mdt']:IsCidFelon()

RegisterCommand("isfelon", function(source, args, rawCommand)
    IsCidFelon(1998, function(res)
    end)
end, false)

RegisterNetEvent('mdt:server:getPenalCode', function()
    local src = source
    TriggerClientEvent('mdt:client:getPenalCode', src, Config.PenalCodeTitles, Config.PenalCode)
end)

RegisterNetEvent('mdt:server:setCallsign', function(cid, newcallsign)
    local player = Framework.GetPlayerByCitizenId(cid)
    Framework.SetPlayerCallSignByPlayer(player, newcallsign)
end)

RegisterNetEvent('mdt:server:saveIncident', function(id, title, information, tags, officers, civilians, evidence, associated, time)
    local src = source
    local player = Framework.GetPlayerByServerId(src)
    if player then
        local playerJobName = Framework.GetPlayerJobNameByPlayer(player)
        if GetJobType(playerJobName) == 'police' then
            if id == 0 then
                local fullname = Framework.GetPlayerFullNameByPlayer(player)
                MySQL.insert('INSERT INTO `mdt_incidents` (`author`, `title`, `details`, `tags`, `officersinvolved`, `civsinvolved`, `evidence`, `time`, `jobtype`) VALUES (:author, :title, :details, :tags, :officersinvolved, :civsinvolved, :evidence, :time, :jobtype)',
                {
                    author = fullname,
                    title = title,
                    details = information,
                    tags = json.encode(tags),
                    officersinvolved = json.encode(officers),
                    civsinvolved = json.encode(civilians),
                    evidence = json.encode(evidence),
                    time = time,
                    jobtype = 'police',
                }, function(infoResult)
                    if infoResult then
                        for i=1, #associated do
                            MySQL.insert('INSERT INTO `mdt_convictions` (`cid`, `linkedincident`, `warrant`, `guilty`, `processed`, `associated`, `charges`, `fine`, `sentence`, `recfine`, `recsentence`, `time`) VALUES (:cid, :linkedincident, :warrant, :guilty, :processed, :associated, :charges, :fine, :sentence, :recfine, :recsentence, :time)', {
                                cid = associated[i]['Cid'],
                                linkedincident = infoResult,
                                warrant = associated[i]['Warrant'],
                                guilty = associated[i]['Guilty'],
                                processed = associated[i]['Processed'],
                                associated = associated[i]['Isassociated'],
                                charges = json.encode(associated[i]['Charges']),
                                fine = tonumber(associated[i]['Fine']),
                                sentence = tonumber(associated[i]['Sentence']),
                                recfine = tonumber(associated[i]['recfine']),
                                recsentence = tonumber(associated[i]['recsentence']),
                                time = time
                            })
                        end
                        TriggerClientEvent('mdt:client:updateIncidentDbId', src, infoResult)
                        --TriggerEvent('mdt:server:AddLog', "A vehicle with the plate ("..plate..") was added to the vehicle information database by "..player['fullname'])
                    end
                end)
            elseif id > 0 then
                MySQL.update("UPDATE mdt_incidents SET title=:title, details=:details, civsinvolved=:civsinvolved, tags=:tags, officersinvolved=:officersinvolved, evidence=:evidence WHERE id=:id", {
                    title = title,
                    details = information,
                    tags = json.encode(tags),
                    officersinvolved = json.encode(officers),
                    civsinvolved = json.encode(civilians),
                    evidence = json.encode(evidence),
                    id = id
                })
                for i=1, #associated do
                    TriggerEvent('mdt:server:handleExistingConvictions', associated[i], id, time)
                end
            end
        end
    end
end)

RegisterNetEvent('mdt:server:handleExistingConvictions', function(data, incidentId, time)
    MySQL.query('SELECT * FROM mdt_convictions WHERE cid=:cid AND linkedincident=:linkedincident', {
        cid = data['Cid'],
        linkedincident = incidentId
    }, function(convictionRes)
        if convictionRes and convictionRes[1] and convictionRes[1]['id'] then
            MySQL.update('UPDATE mdt_convictions SET cid=:cid, linkedincident=:linkedincident, warrant=:warrant, guilty=:guilty, processed=:processed, associated=:associated, charges=:charges, fine=:fine, sentence=:sentence, recfine=:recfine, recsentence=:recsentence WHERE cid=:cid AND linkedincident=:linkedincident', {
                cid = data['Cid'],
                linkedincident = incidentId,
                warrant = data['Warrant'],
                guilty = data['Guilty'],
                processed = data['Processed'],
                associated = data['Isassociated'],
                charges = json.encode(data['Charges']),
                fine = tonumber(data['Fine']),
                sentence = tonumber(data['Sentence']),
                recfine = tonumber(data['recfine']),
                recsentence = tonumber(data['recsentence']),
            })
        else
            MySQL.insert('INSERT INTO `mdt_convictions` (`cid`, `linkedincident`, `warrant`, `guilty`, `processed`, `associated`, `charges`, `fine`, `sentence`, `recfine`, `recsentence`, `time`) VALUES (:cid, :linkedincident, :warrant, :guilty, :processed, :associated, :charges, :fine, :sentence, :recfine, :recsentence, :time)', {
                cid = data['Cid'],
                linkedincident = incidentId,
                warrant = data['Warrant'],
                guilty = data['Guilty'],
                processed = data['Processed'],
                associated = data['Isassociated'],
                charges = json.encode(data['Charges']),
                fine = tonumber(data['Fine']),
                sentence = tonumber(data['Sentence']),
                recfine = tonumber(data['recfine']),
                recsentence = tonumber(data['recsentence']),
                time = time
            })
        end
    end)
end)

RegisterNetEvent('mdt:server:removeIncidentCriminal', function(cid, incident)
    MySQL.update('DELETE FROM mdt_convictions WHERE cid=:cid AND linkedincident=:linkedincident', {
        cid = cid,
        linkedincident = incident
    })
end)

-- Dispatch

RegisterNetEvent('mdt:server:setWaypoint', function(callid)
    local src = source
    local player = Framework.GetPlayerByServerId(src)
    local playerJobName = Framework.GetPlayerJobNameByPlayer(player)
    local JobType = GetJobType(playerJobName)
    if JobType == 'police' or JobType == 'ambulance' then
        if callid then
            if isDispatchRunning then
                local calls = exports['ps-dispatch']:GetDispatchCalls()
                TriggerClientEvent('mdt:client:setWaypoint', src, calls[callid])
            end
        end
    end
end)

RegisterNetEvent('mdt:server:callDetach', function(callid)
    local src = source
    local player = Framework.GetPlayerByServerId(src)
    local playerdata = {
        fullname = Framework.GetPlayerFullNameByPlayer(player),
        job = Framework.GetPlayerJobObjectAsQbByPlayer(player),
        cid = Framework.GetPlayerCitizenIdByPlayer(player),
        callsign = Framework.GetPlayerCallSignByPlayer(player)
    }
    local JobType = GetJobType(Framework.GetPlayerJobNameByPlayer(player))
    if JobType == 'police' or JobType == 'ambulance' then
        if callid then
            TriggerEvent('dispatch:removeUnit', callid, playerdata, function(newNum)
                TriggerClientEvent('mdt:client:callDetach', -1, callid, newNum)
            end)
        end
    end
end)

RegisterNetEvent('mdt:server:callAttach', function(callid)
    local src = source
    local player = Framework.GetPlayerByServerId(src)
    local playerdata = {
        fullname = Framework.GetPlayerFullNameByPlayer(player),
        job = Framework.GetPlayerJobObjectAsQbByPlayer(player),
        cid = Framework.GetPlayerCitizenIdByPlayer(player),
        callsign = Framework.GetPlayerCallSignByPlayer(player)
    }
    local JobType = GetJobType(Framework.GetPlayerJobNameByPlayer(player))
    if JobType == 'police' or JobType == 'ambulance' then
        if callid then
            TriggerEvent('dispatch:addUnit', callid, playerdata, function(newNum)
                TriggerClientEvent('mdt:client:callAttach', -1, callid, newNum)
            end)
        end
    end

end)

RegisterNetEvent('mdt:server:attachedUnits', function(callid)
    local src = source
    local player = Framework.GetPlayerByServerId(src)
    local JobType = GetJobType(Framework.GetPlayerJobNameByPlayer(player))
    if JobType == 'police' or JobType == 'ambulance' then
        if callid then
            if isDispatchRunning then
                local calls = exports['ps-dispatch']:GetDispatchCalls()
                TriggerClientEvent('mdt:client:attachedUnits', src, calls[callid]['units'], callid)
            end
        end
    end
end)

RegisterNetEvent('mdt:server:callDispatchDetach', function(callid, cid)
    local src = source
    local player = Framework.GetPlayerByServerId(src)
    local playerdata = {
        fullname = Framework.GetPlayerFullNameByPlayer(player),
        job = Framework.GetPlayerJobObjectAsQbByPlayer(player),
        cid = Framework.GetPlayerCitizenIdByPlayer(player),
        callsign = Framework.GetPlayerCallSignByPlayer(player)
    }
    local callid = tonumber(callid)
    local JobType = GetJobType(Framework.GetPlayerJobNameByPlayer(player))
    if JobType == 'police' or JobType == 'ambulance' then
        if callid then
            TriggerEvent('dispatch:removeUnit', callid, playerdata, function(newNum)
                TriggerClientEvent('mdt:client:callDetach', -1, callid, newNum)
            end)
        end
    end
end)

RegisterNetEvent('mdt:server:setDispatchWaypoint', function(callid, cid)
    local src = source
    local player = Framework.GetPlayerByServerId(src)
    local callid = tonumber(callid)
    local JobType = GetJobType(Framework.GetPlayerJobNameByPlayer(player))
    if JobType == 'police' or JobType == 'ambulance' then
        if callid then
            if isDispatchRunning then
                local calls = exports['ps-dispatch']:GetDispatchCalls()
                TriggerClientEvent('mdt:client:setWaypoint', src, calls[callid])
            end
        end
    end

end)

RegisterNetEvent('mdt:server:callDragAttach', function(callid, cid)
    local src = source
    local player = Framework.GetPlayerByServerId(src)
    local playerdata = {
        name = Framework.GetPlayerFullNameByPlayer(player),
        job = Framework.GetPlayerJobObjectAsQbByPlayer(player),
        cid = Framework.GetPlayerCitizenIdByPlayer(player),
        callsign = Framework.GetPlayerCallSignByPlayer(player)
    }
    local callid = tonumber(callid)
    local JobType = GetJobType(Framework.GetPlayerJobNameByPlayer(player))
    if JobType == 'police' or JobType == 'ambulance' then
        if callid then
            TriggerEvent('dispatch:addUnit', callid, playerdata, function(newNum)
                TriggerClientEvent('mdt:client:callAttach', -1, callid, newNum)
            end)
        end
    end
end)

RegisterNetEvent('mdt:server:setWaypoint:unit', function(cid)
    local src = source
    local player = Framework.GetPlayerByCitizenId(cid)
    local PlayerCoords = GetEntityCoords(GetPlayerPed(Framework.GetPlayerServerIdByPlayer(player)))
    TriggerClientEvent("mdt:client:setWaypoint:unit", src, PlayerCoords)
end)

-- Dispatch chat

RegisterNetEvent('mdt:server:sendMessage', function(message, time)
    if message and time then
        local src = source
        local player = Framework.GetPlayerByServerId(src)
        if player then
            MySQL.scalar("SELECT pfp FROM `mdt_data` WHERE cid=:id LIMIT 1", {
                id = Framework.GetPlayerCitizenIdByPlayer(player) -- % wildcard, needed to search for all alike results
            }, function(data)
                if data == "" then data = nil end
                local ProfilePicture = ProfPic(Framework.GetPlayerGenderByPlayer(player), data)
                local callsign = Framework.GetPlayerCallSignByPlayer(player) or "000"
                local Item = {
                    profilepic = ProfilePicture,
                    callsign = Framework.GetPlayerCallSignByPlayer(player),
                    cid = Framework.GetPlayerCitizenIdByPlayer(player),
                    name = '('..callsign..') '..Framework.GetPlayerFullNameByPlayer(player),
                    message = message,
                    time = time,
                    job = Framework.GetPlayerJobNameByPlayer(player)
                }
                dispatchMessages[#dispatchMessages+1] = Item
                TriggerClientEvent('mdt:client:dashboardMessage', -1, Item)
            end)
        end
    end
end)

RegisterNetEvent('mdt:server:refreshDispatchMsgs', function()
    local src = source
    local player = Framework.GetPlayerByServerId(src)
    local playerJobName = Framework.GetPlayerJobNameByPlayer(player)
    if IsJobAllowedToMDT(playerJobName) then
        TriggerClientEvent('mdt:client:dashboardMessages', src, dispatchMessages)
    end
end)

RegisterNetEvent('mdt:server:getCallResponses', function(callid)
    local src = source
    local player = Framework.GetPlayerByServerId(src)
    local playerJobName = Framework.GetPlayerJobNameByPlayer(player)
    if IsPoliceOrEms(playerJobName) then
        if isDispatchRunning then
            local calls = exports['ps-dispatch']:GetDispatchCalls()
            TriggerClientEvent('mdt:client:getCallResponses', src, calls[callid]['responses'], callid)
        end
    end
end)

RegisterNetEvent('mdt:server:sendCallResponse', function(message, time, callid)
    local src = source
    local player = Framework.GetPlayerByServerId(src)
    local playerJobName = Framework.GetPlayerJobNameByPlayer(player)
    local name = Framework.GetPlayerFullNameByPlayer(player)
    if IsPoliceOrEms(playerJobName) then
        TriggerEvent('dispatch:sendCallResponse', src, callid, message, time, function(isGood)
            if isGood then
                TriggerClientEvent('mdt:client:sendCallResponse', -1, message, time, callid, name)
            end
        end)
    end
end)

RegisterNetEvent('mdt:server:setRadio', function(cid, newRadio)
    local src = source
    local targetPlayer = Framework.GetPlayerByCitizenId(cid)
    local targetSource = Framework.GetPlayerServerIdByPlayer(targetPlayer)
    local targetName = Framework.GetPlayerFullNameByPlayer(targetPlayer)

    local radio = Framework.GetPlayerHasItemByPlayer(targetPlayer, "radio")
    if radio then
        TriggerClientEvent('mdt:client:setRadio', targetSource, newRadio)
    else
        Framework.Notification(src, targetName..' does not have a radio!', 'error')
    end
end)

local function isRequestVehicle(vehId)
    local found = false
    for i=1, #impound do
        if impound[i]['vehicle'] == vehId then
            found = true
            impound[i] = nil
            break
        end
    end
    return found
end
exports('isRequestVehicle', isRequestVehicle)

RegisterNetEvent('mdt:server:impoundVehicle', function(sentInfo, sentVehicle)
    local src = source
    local player = Framework.GetPlayerByServerId(src)
    if player then
        local playerJobName = Framework.GetPlayerJobNameByPlayer(player)
        if GetJobType(playerJobName) == 'police' then
            if sentInfo and type(sentInfo) == 'table' then
                local plate, linkedreport, fee, time = sentInfo['plate'], sentInfo['linkedreport'], sentInfo['fee'], sentInfo['time']
                if (plate and linkedreport and fee and time) then
                    local vehicle = SearchVehicleDataByPlate(plate)
                    if vehicle and vehicle[1] then
                        local data = vehicle[1]
                        MySQL.insert('INSERT INTO `mdt_impound` (`vehicleid`, `linkedreport`, `fee`, `time`) VALUES (:vehicleid, :linkedreport, :fee, :time)', {
                            vehicleid = data['id'],
                            linkedreport = linkedreport,
                            fee = fee,
                            time = os.time() + (time * 60)
                        }, function(res)
                            local data = {
                                vehicleid = data['id'],
                                plate = plate,
                                beingcollected = 0,
                                vehicle = sentVehicle,
                                officer = Framework.GetPlayerFullNameByPlayer(player),
                                number = Framework.GetPlayerPhoneNumberByPlayer(player),
                                time = os.time() * 1000,
                                src = src,
                            }
                            local vehicle = NetworkGetEntityFromNetworkId(sentVehicle)
                            FreezeEntityPosition(vehicle, true)
                            impound[#impound+1] = data

                            TriggerClientEvent("police:client:ImpoundVehicle", src, true, fee) -- TODO: change this once esx bridge is setup
                        end)
                    end
                end
            end
        end
    end
end)

RegisterNetEvent('mdt:server:getImpoundVehicles', function()
    TriggerClientEvent('mdt:client:getImpoundVehicles', source, impound)
end)

RegisterNetEvent('mdt:server:removeImpound', function(plate, currentSelection)
    print("Removing impound", plate, currentSelection)
    local src = source
    local player = Framework.GetPlayerByServerId(src)
    if player then
        local playerJobName = Framework.GetPlayerJobNameByPlayer(player)
        if GetJobType(playerJobName) == 'police' then
            local result = SearchVehicleDataByPlate(plate)
            if result and result[1] then
                local data = result[1]
                MySQL.update("DELETE FROM `mdt_impound` WHERE vehicleid=:vehicleid", { vehicleid = data['id'] })
                TriggerClientEvent('police:client:TakeOutImpound', src, currentSelection)
            end
        end
    end
end)

RegisterNetEvent('mdt:server:statusImpound', function(plate)
    local src = source
    local player = Framework.GetPlayerByServerId(src)
    if player then
        local playerJobName = Framework.GetPlayerJobNameByPlayer(player)
        if GetJobType(playerJobName) == 'police' then
            local vehicle = SearchVehicleDataByPlate(plate)
            if vehicle and vehicle[1] then
                local data = vehicle[1]
                local impoundinfo = MySQL.query.await("SELECT * FROM `mdt_impound` WHERE vehicleid=:vehicleid LIMIT 1", { vehicleid = data['id'] })
                if impoundinfo and impoundinfo[1] then
                    TriggerClientEvent('mdt:client:statusImpound', src, impoundinfo[1], plate)
                end
            end
        end
    end
end)

RegisterServerEvent("mdt:server:AddLog", function(text)
    AddLog(text)
end)

-- Returns the source for the given citizenId
Framework.CreateServerCallback('mdt:server:GetPlayerSourceId', function(source, cb, targetCitizenId)
    local targetPlayer = Framework.GetPlayerByCitizenId(targetCitizenId)
    if targetPlayer == nil then
        Framework.Notification(source, "Citizen seems Asleep / Missing", "error")
        return
    end
    local targetSource = Framework.GetPlayerServerIdByPlayer(targetPlayer)

    cb(targetSource)
end)

Framework.CreateServerCallback('getWeaponInfo', function(source, cb) -- CHECK: I don't get this. It's supposed to get weapon data but no info is being sent to it by client. It looks like it check for a random weapon!
    local player = Framework.GetPlayerByServerId(source)
    local weaponInfo = nil
    for _, item in pairs(player.PlayerData.items) do -- TODO: refactor this to be compatible with all frameworks such as esx...I cbf now
        if item.type == "weapon" then
            local invImage = ("https://cfx-nui-%s/html/images/%s"):format(Config.InventoryForWeaponsImages, item.image) -- TODO: move image directory into config
            if invImage then
                weaponInfo = {
                    serialnumber = item.info.serie,
                    owner = Framework.GetPlayerFullNameByPlayer(player),
                    weaponmodel = QBCore.Shared.Items[item.name].label,
                    weaponurl = invImage,
                    notes = "Self Registered",
                    weapClass = "Class 1",
                }
                break
            end
        end
    end
    if weaponInfo then
        Framework.Notification(source, "Weapon has been added to police database. ")
    else
        Framework.Notification(source, "Weapon already registered on database.")
    end

    cb(weaponInfo)
end)

RegisterNetEvent('mdt:server:registerweapon', function(serial, imageurl, notes, owner, weapClass, weapModel) 
    exports['ps-mdt']:CreateWeaponInfo(serial, imageurl, notes, owner, weapClass, weapModel)
end)

RegisterNetEvent('mdt:server:removeMoney', function(citizenId, fine) -- CHECK: hello server exploit!
    local src = source
    local player = Framework.GetPlayerByCitizenId(citizenId)

    if not player then return end

    local playerSource = Framework.GetPlayerServerIdByPlayer(player)

    if Framework.RemoveMoneyFromPlayer(player, fine, 'bank', 'lspd-fine') then
        Framework.Notification(playerSource, fine.."$ were removed from your Bank Account.")
    end
end)

function getTopOfficers(callback)
    local result = {}
    local query = 'SELECT * FROM mdt_clocking ORDER BY total_time DESC LIMIT 10'
    MySQL.Async.fetchAll(query, {}, function(officers)
        for k, officer in ipairs(officers) do
            table.insert(result, {
                rank = k,
                name = officer.firstname .. " " .. officer.lastname,
                callsign = officer.user_id,
                totalTime = format_time(officer.total_time)
            })
        end
        callback(result)
    end)
end

RegisterServerEvent("mdt:requestOfficerData")
AddEventHandler("mdt:requestOfficerData", function()
    local src = source
    getTopOfficers(function(officerData)
        TriggerClientEvent("mdt:receiveOfficerData", src, officerData)
    end)
end)

function sendToDiscord(color, name, message, footer)
    local embed = {
          {
              color = color,
              title = "**".. name .."**",
              description = message,
              footer = {
                  text = footer,
              },
          }
      }
  
    PerformHttpRequest(Config.ClockinWebhook, function(err, text, headers) end, 'POST', json.encode({username = name, embeds = embed}), { ['Content-Type'] = 'application/json' })
end

function format_time(time)
    local hours = math.floor(time / 3600)
    local minutes = math.floor((time % 3600) / 60)
    local seconds = time % 60
    return string.format('%02d:%02d:%02d', hours, minutes, seconds)
end
