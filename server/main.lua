local QBCore = exports['qb-core']:GetCoreObject()
local incidents = {}
local convictions = {}
local bolos = {}
local MugShots = {}
local activeUnits = {}
local impound = {}
local dispatchMessages = {}
local isDispatchRunning = false
local antiSpam = false

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
		local Player = QBCore.Functions.GetPlayer(src)
		local PlayerData = GetPlayerData(src)
		local vehicleOwner = GetVehicleOwner(plate)
		local bolo, title, boloId = GetBoloStatus(plate)
		local warrant, owner, incidentId = GetWarrantStatus(plate)
		local driversLicense = PlayerData.metadata['licences'].driver

		if bolo == true then
			TriggerClientEvent('QBCore:Notify', src, 'BOLO ID: '..boloId..' | Title: '..title..' | Registered Owner: '..vehicleOwner..' | Plate: '..plate, 'error', Config.WolfknightNotifyTime)
		end
		if warrant == true then
			TriggerClientEvent('QBCore:Notify', src, 'WANTED - INCIDENT ID: '..incidentId..' | Registered Owner: '..owner..' | Plate: '..plate, 'error', Config.WolfknightNotifyTime)
		end

		if Config.PlateScanForDriversLicense and driversLicense == false and vehicleOwner then
			TriggerClientEvent('QBCore:Notify', src, 'NO DRIVERS LICENCE | Registered Owner: '..vehicleOwner..' | Plate: '..plate, 'error', Config.WolfknightNotifyTime)
		end

		if bolo or warrant or (Config.PlateScanForDriversLicense and not driversLicense) then
			TriggerClientEvent("wk:togglePlateLock", src, cam, true, 1)
		end
	end)
end

AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
	Wait(3000)
	if Config.MugShotWebhook == '' then
		print("\27[31mA webhook is missing in: Config.MugShotWebhook\27[0m")
    end
    if Config.ClockinWebhook == '' then
		print("\27[31mA webhook is missing in: Config.ClockinWebhook\27[0m")
	end
end)

RegisterNetEvent("ps-mdt:server:OnPlayerUnload", function()
	--// Delete player from the MDT on logout
	local src = source
	local player = QBCore.Functions.GetPlayer(src)
	if GetActiveData(player.PlayerData.citizenid) then
		activeUnits[player.PlayerData.citizenid] = nil
	end
end)

AddEventHandler('playerDropped', function(reason)
    local src = source
    local PlayerData = GetPlayerData(src)
	if PlayerData == nil then return end -- Player not loaded in correctly and dropped early

    local time = os.date("%Y-%m-%d %H:%M:%S")
    local job = PlayerData.job.name
    local firstName = PlayerData.charinfo.firstname:sub(1,1):upper()..PlayerData.charinfo.firstname:sub(2)
    local lastName = PlayerData.charinfo.lastname:sub(1,1):upper()..PlayerData.charinfo.lastname:sub(2)

    -- Auto clock out if the player is off duty
     if IsPoliceOrEms(job) and PlayerData.job.onduty then
		MySQL.query.await('UPDATE mdt_clocking SET clock_out_time = NOW(), total_time = TIMESTAMPDIFF(SECOND, clock_in_time, NOW()) WHERE user_id = @user_id ORDER BY id DESC LIMIT 1', {
			['@user_id'] = PlayerData.citizenid
		})

		local result = MySQL.scalar.await('SELECT total_time FROM mdt_clocking WHERE user_id = @user_id', {
			['@user_id'] = PlayerData.citizenid
		})
		if result then
			local time_formatted = format_time(tonumber(result))
			sendToDiscord(16711680, "MDT Clock-Out", 'Player: **' ..  firstName .. " ".. lastName .. '**\n\nJob: **' .. PlayerData.job.name .. '**\n\nRank: **' .. PlayerData.job.grade.name .. '**\n\nStatus: **Off Duty**\n Total time:' .. time_formatted, "ps-mdt | Made by Project Sloth")
		end
	end

    -- Delete player from the MDT on logout
    if PlayerData ~= nil then
        if GetActiveData(PlayerData.citizenid) then
            activeUnits[PlayerData.citizenid] = nil
        end
    else
        local license = QBCore.Functions.GetIdentifier(src, "license")
        local citizenids = GetCitizenID(license)

        for _, v in pairs(citizenids) do
            if GetActiveData(v.citizenid) then
                activeUnits[v.citizenid] = nil
            end
        end
    end
end)

RegisterNetEvent("ps-mdt:server:ToggleDuty", function()
    local src = source
    local player = QBCore.Functions.GetPlayer(src)
    if not player.PlayerData.job.onduty then
	--// Remove from MDT
	if GetActiveData(player.PlayerData.citizenid) then
		activeUnits[player.PlayerData.citizenid] = nil
	end
    end
end)

QBCore.Commands.Add("mdtleaderboard", "Show MDT leaderboard", {}, false, function(source, args)
    local PlayerData = GetPlayerData(source)
    local job = PlayerData.job.name

    if not IsPoliceOrEms(job) then
        TriggerClientEvent('QBCore:Notify', source, "You don't have permission to use this command.", 'error')
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
    TriggerClientEvent('QBCore:Notify', source, "MDT leaderboard sent to Discord!", 'success')
end)

RegisterNetEvent("ps-mdt:server:ClockSystem", function()
    local src = source
    local PlayerData = GetPlayerData(src)
    local time = os.date("%Y-%m-%d %H:%M:%S")
    local firstName = PlayerData.charinfo.firstname:sub(1,1):upper()..PlayerData.charinfo.firstname:sub(2)
    local lastName = PlayerData.charinfo.lastname:sub(1,1):upper()..PlayerData.charinfo.lastname:sub(2)
    if PlayerData.job.onduty then
        
        TriggerClientEvent('QBCore:Notify', source, "You're clocked-in", 'success')
		MySQL.Async.insert('INSERT INTO mdt_clocking (user_id, firstname, lastname, clock_in_time) VALUES (:user_id, :firstname, :lastname, :clock_in_time) ON DUPLICATE KEY UPDATE user_id = :user_id, firstname = :firstname, lastname = :lastname, clock_in_time = :clock_in_time', {
			user_id = PlayerData.citizenid,
			firstname = firstName,
			lastname = lastName,
			clock_in_time = time
		}, function()
		end)
		sendToDiscord(65280, "MDT Clock-In", 'Player: **' ..  firstName .. " ".. lastName .. '**\n\nJob: **' .. PlayerData.job.name .. '**\n\nRank: **' .. PlayerData.job.grade.name .. '**\n\nStatus: **On Duty**', "ps-mdt | Made by Project Sloth")
    else
		TriggerClientEvent('QBCore:Notify', source, "You're clocked-out", 'success')
		MySQL.query.await('UPDATE mdt_clocking SET clock_out_time = NOW(), total_time = TIMESTAMPDIFF(SECOND, clock_in_time, NOW()) WHERE user_id = @user_id ORDER BY id DESC LIMIT 1', {
			['@user_id'] = PlayerData.citizenid
		})

		local result = MySQL.scalar.await('SELECT total_time FROM mdt_clocking WHERE user_id = @user_id', {
			['@user_id'] = PlayerData.citizenid
		})
		local time_formatted = format_time(tonumber(result))

		sendToDiscord(16711680, "MDT Clock-Out", 'Player: **' ..  firstName .. " ".. lastName .. '**\n\nJob: **' .. PlayerData.job.name .. '**\n\nRank: **' .. PlayerData.job.grade.name .. '**\n\nStatus: **Off Duty**\n Total time:' .. time_formatted, "ps-mdt | Made by Project Sloth")
    end
end)

RegisterNetEvent('mdt:server:openMDT', function()
	local src = source
	local PlayerData = GetPlayerData(src)
	if not PermCheck(src, PlayerData) then return end
	local Radio = Player(src).state.radioChannel or 0

	activeUnits[PlayerData.citizenid] = {
		cid = PlayerData.citizenid,
		callSign = PlayerData.metadata['callsign'],
		firstName = PlayerData.charinfo.firstname:sub(1,1):upper()..PlayerData.charinfo.firstname:sub(2),
		lastName = PlayerData.charinfo.lastname:sub(1,1):upper()..PlayerData.charinfo.lastname:sub(2),
		radio = Radio,
		unitType = PlayerData.job.name,
		duty = PlayerData.job.onduty
	}

	local JobType = GetJobType(PlayerData.job.name)
	local bulletin = GetBulletins(JobType)
	local calls = exports['ps-dispatch']:GetDispatchCalls()
	TriggerClientEvent('mdt:client:open', src, bulletin, activeUnits, calls, PlayerData.citizenid)
end)

QBCore.Functions.CreateCallback('mdt:server:SearchProfile', function(source, cb, sentData)
    if not sentData then  return cb({}) end
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if Player then
        local JobType = GetJobType(Player.PlayerData.job.name)
        if JobType ~= nil then
            local people = MySQL.query.await("SELECT p.citizenid, p.charinfo, md.pfp, md.fingerprint FROM players p LEFT JOIN mdt_data md on p.citizenid = md.cid WHERE LOWER(CONCAT(JSON_VALUE(p.charinfo, '$.firstname'), ' ', JSON_VALUE(p.charinfo, '$.lastname'))) LIKE :query OR LOWER(`charinfo`) LIKE :query OR LOWER(`citizenid`) LIKE :query OR LOWER(md.fingerprint) LIKE :query AND jobtype = :jobtype LIMIT 20", { query = string.lower('%'..sentData..'%'), jobtype = JobType })
            local citizenIds = {}
            local citizenIdIndexMap = {}
            if not next(people) then cb({}) return end

            for index, data in pairs(people) do
                people[index]['warrant'] = false
                people[index]['convictions'] = 0
                people[index]['licences'] = GetPlayerLicenses(data.citizenid)
                people[index]['pp'] = ProfPic(data.gender, data.pfp)
				if data.fingerprint and data.fingerprint ~= "" then
					people[index]['fingerprint'] = data.fingerprint
				else
					people[index]['fingerprint'] = ""
				end				
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
			TriggerClientEvent('mdt:client:searchProfile', src, people, false)

            return cb(people)
        end
    end

    return cb({})
end)

QBCore.Functions.CreateCallback("mdt:server:getWarrants", function(source, cb)
    local WarrantData = {}
    local data = MySQL.query.await("SELECT * FROM mdt_convictions", {})
    for _, value in pairs(data) do
        if value.warrant == "1" then
			WarrantData[#WarrantData+1] = {
                cid = value.cid,
                linkedincident = value.linkedincident,
                name = GetNameFromId(value.cid),
                time = value.time
            }
        end
    end
    cb(WarrantData)
end)

QBCore.Functions.CreateCallback('mdt:server:OpenDashboard', function(source, cb)
	local PlayerData = GetPlayerData(source)
	if not PermCheck(source, PlayerData) then return end
	local JobType = GetJobType(PlayerData.job.name)
	local bulletin = GetBulletins(JobType)
	cb(bulletin)
end)

RegisterNetEvent('mdt:server:NewBulletin', function(title, info, time)
	local src = source
	local PlayerData = GetPlayerData(src)
	if not PermCheck(src, PlayerData) then return end
	local JobType = GetJobType(PlayerData.job.name)
	local playerName = GetNameFromPlayerData(PlayerData)
	local newBulletin = MySQL.insert.await('INSERT INTO `mdt_bulletin` (`title`, `desc`, `author`, `time`, `jobtype`) VALUES (:title, :desc, :author, :time, :jt)', {
		title = title,
		desc = info,
		author = playerName,
		time = tostring(time),
		jt = JobType
	})

	AddLog(("A new bulletin was added by %s with the title: %s!"):format(playerName, title))
	TriggerClientEvent('mdt:client:newBulletin', -1, src, {id = newBulletin, title = title, info = info, time = time, author = PlayerData.CitizenId}, JobType)
end)

RegisterNetEvent('mdt:server:deleteBulletin', function(id, title)
	if not id then return false end
	local src = source
	local PlayerData = GetPlayerData(src)
	if not PermCheck(src, PlayerData) then return end
	local JobType = GetJobType(PlayerData.job.name)

	MySQL.query.await('DELETE FROM `mdt_bulletin` where id = ?', {id})
	AddLog("Bulletin with Title: "..title.." was deleted by " .. GetNameFromPlayerData(PlayerData) .. ".")
end)

QBCore.Functions.CreateCallback('mdt:server:GetProfileData', function(source, cb, sentId)
	if not sentId then return cb({}) end

	local src = source
	local PlayerData = GetPlayerData(src)
	if not PermCheck(src, PlayerData) then return cb({}) end
	local JobType = GetJobType(PlayerData.job.name)
	local target = GetPlayerDataById(sentId)
	local JobName = PlayerData.job.name

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

	local job, grade = UnpackJob(target.job)

	local apartmentData = GetPlayerApartment(target.citizenid)

	if Config.UsingDefaultQBApartments and apartmentData then
		apartmentData = apartmentData[1].label .. ' (' ..apartmentData[1].name..')'
	end

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

	if Config.PoliceJobs[JobName] or Config.DojJobs[JobName] then
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
		local properties= GetPlayerProperties(person.cid)
		for k, v in pairs(properties) do
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
			person.properties = Houses
	end

	local mdtData = GetPersonInformation(sentId, JobType)
	if mdtData then
		person.mdtinfo = mdtData.information
		person.profilepic = mdtData.pfp
		person.tags = json.decode(mdtData.tags)
		person.gallery = json.decode(mdtData.gallery)
		person.fingerprint = mdtData.fingerprint
		print("Fetched fingerprint from mdt_data:", mdtData.fingerprint)
	end

	return cb(person)
end)

RegisterNetEvent("mdt:server:saveProfile", function(pfp, information, cid, fName, sName, tags, gallery, licenses, fingerprint)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    UpdateAllLicenses(cid, licenses)
    if Player then
        local JobType = GetJobType(Player.PlayerData.job.name)
        if JobType == 'doj' then JobType = 'police' end

        MySQL.Async.insert('INSERT INTO mdt_data (cid, information, pfp, jobtype, tags, gallery, fingerprint) VALUES (:cid, :information, :pfp, :jobtype, :tags, :gallery, :fingerprint) ON DUPLICATE KEY UPDATE cid = :cid, information = :information, pfp = :pfp, jobtype = :jobtype, tags = :tags, gallery = :gallery, fingerprint = :fingerprint', {
            cid = cid,
            information = information,
            pfp = pfp,
            jobtype = JobType,
            tags = json.encode(tags),
            gallery = json.encode(gallery),
            fingerprint = fingerprint,
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
    MySQL.Async.insert('INSERT INTO mdt_data (cid, pfp, gallery, tags) VALUES (:cid, :pfp, :gallery, :tags) ON DUPLICATE KEY UPDATE cid = :cid,  pfp = :pfp, tags = :tags, gallery = :gallery', {
		cid = cid,
		pfp = MugShotURLs[1],
		tags = json.encode(tags),
		gallery = json.encode(MugShotURLs),
	})
end)

RegisterNetEvent("mdt:server:updateLicense", function(cid, type, status)
	local src = source
	local Player = QBCore.Functions.GetPlayer(src)
	if Player then
		if GetJobType(Player.PlayerData.job.name) == 'police' then
			ManageLicense(cid, type, status)
		end
	end
end)

-- Incidents

RegisterNetEvent('mdt:server:getAllIncidents', function()
	local src = source
	local Player = QBCore.Functions.GetPlayer(src)
	if Player then
		local JobType = GetJobType(Player.PlayerData.job.name)
		if JobType == 'police' or JobType == 'doj' then
			local matches = MySQL.query.await("SELECT * FROM `mdt_incidents` ORDER BY `id` DESC LIMIT 30", {})

			TriggerClientEvent('mdt:client:getAllIncidents', src, matches)
		end
	end
end)

RegisterNetEvent('mdt:server:searchIncidents', function(query)
	if query then
		local src = source
		local Player = QBCore.Functions.GetPlayer(src)
		if Player then
			local JobType = GetJobType(Player.PlayerData.job.name)
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
		local Player = QBCore.Functions.GetPlayer(src)
		if Player then
			local JobType = GetJobType(Player.PlayerData.job.name)
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
						local res = GetNameFromId(convictions[i]['cid'])
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
	local Player = QBCore.Functions.GetPlayer(src)
	local JobType = GetJobType(Player.PlayerData.job.name)
	if JobType == 'police' or JobType == 'ambulance' then
		local matches = MySQL.query.await("SELECT * FROM `mdt_bolos` WHERE jobtype = :jobtype", {jobtype = JobType})
		TriggerClientEvent('mdt:client:getAllBolos', src, matches)
	end
end)

RegisterNetEvent('mdt:server:searchBolos', function(sentSearch)
	if sentSearch then
		local src = source
		local Player = QBCore.Functions.GetPlayer(src)
		local JobType = GetJobType(Player.PlayerData.job.name)
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
		local Player = QBCore.Functions.GetPlayer(src)
		local JobType = GetJobType(Player.PlayerData.job.name)
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
		local Player = QBCore.Functions.GetPlayer(src)
		local JobType = GetJobType(Player.PlayerData.job.name)
		if JobType == 'police' or JobType == 'ambulance' then
			local fullname = Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname

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
		local Player = QBCore.Functions.GetPlayer(src)
		if Config.RemoveWeaponsPerms[Player.PlayerData.job.name] then
			if Config.RemoveWeaponsPerms[Player.PlayerData.job.name][Player.PlayerData.job.grade.level] then
				local fullName = Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname
				MySQL.update("DELETE FROM `mdt_weaponinfo` WHERE id=:id", { id = id })
				TriggerEvent('mdt:server:AddLog', "A Weapon Info was deleted by "..fullName.." with the ID ("..id..")")
			else
				local fullname = Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname
				TriggerClientEvent("QBCore:Notify", src, 'No Permissions to do that!', 'error')
				TriggerEvent('mdt:server:AddLog', fullname.." tryed to delete a Weapon Info with the ID ("..id..")")
			end
		end
	end
end)

RegisterNetEvent('mdt:server:deleteReports', function(id)
	if id then
		local src = source
		local Player = QBCore.Functions.GetPlayer(src)
		if Config.RemoveReportPerms[Player.PlayerData.job.name] then
			if Config.RemoveReportPerms[Player.PlayerData.job.name][Player.PlayerData.job.grade.level] then
				local fullName = Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname
				MySQL.update("DELETE FROM `mdt_reports` WHERE id=:id", { id = id })
				TriggerEvent('mdt:server:AddLog', "A Report was deleted by "..fullName.." with the ID ("..id..")")
			else
				local fullname = Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname
				TriggerClientEvent("QBCore:Notify", src, 'No Permissions to do that!', 'error')
				TriggerEvent('mdt:server:AddLog', fullname.." tryed to delete a Report with the ID ("..id..")")
			end
		end
	end
end)

RegisterNetEvent('mdt:server:deleteIncidents', function(id)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if Config.RemoveIncidentPerms[Player.PlayerData.job.name] then
        if Config.RemoveIncidentPerms[Player.PlayerData.job.name][Player.PlayerData.job.grade.level] then
            local fullName = Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname
            MySQL.update("DELETE FROM `mdt_convictions` WHERE `linkedincident` = :id", {id = id})
            MySQL.update("UPDATE `mdt_convictions` SET `warrant` = '0' WHERE `linkedincident` = :id", {id = id}) -- Delete any outstanding warrants from incidents
            MySQL.update("DELETE FROM `mdt_incidents` WHERE id=:id", { id = id }, function(rowsChanged)
                if rowsChanged > 0 then
                    TriggerEvent('mdt:server:AddLog', "A Incident was deleted by "..fullName.." with the ID ("..id..")")
                end
            end)
        else
            local fullname = Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname
            TriggerClientEvent("QBCore:Notify", src, 'No Permissions to do that!', 'error')
            TriggerEvent('mdt:server:AddLog', fullname.." tried to delete an Incident with the ID ("..id..")")
        end
    end
end)

RegisterNetEvent('mdt:server:deleteBolo', function(id)
	if id then
		local src = source
		local Player = QBCore.Functions.GetPlayer(src)
		local JobType = GetJobType(Player.PlayerData.job.name)
		if JobType == 'police' then
			local fullname = Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname
			MySQL.update("DELETE FROM `mdt_bolos` WHERE id=:id", { id = id, jobtype = JobType })
			TriggerEvent('mdt:server:AddLog', "A BOLO was deleted by "..fullname.." with the ID ("..id..")")
		end
	end
end)

RegisterNetEvent('mdt:server:deleteICU', function(id)
	if id then
		local src = source
		local Player = QBCore.Functions.GetPlayer(src)
		local JobType = GetJobType(Player.PlayerData.job.name)
		if JobType == 'ambulance' then
			local fullname = Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname
			MySQL.update("DELETE FROM `mdt_bolos` WHERE id=:id", { id = id, jobtype = JobType })
			TriggerEvent('mdt:server:AddLog', "A ICU Check-in was deleted by "..fullname.." with the ID ("..id..")")
		end
	end
end)

RegisterNetEvent('mdt:server:incidentSearchPerson', function(query)
    if query then
        local src = source
        local Player = QBCore.Functions.GetPlayer(src)
        if Player then
            local JobType = GetJobType(Player.PlayerData.job.name)
            if JobType == 'police' or JobType == 'doj' or JobType == 'ambulance' then
                local function ProfPic(gender, profilepic)
                    if profilepic then return profilepic end;
                    if gender == "f" then return "img/female.png" end;
                    return "img/male.png"
                end

                local firstname, lastname = query:match("^(%S+)%s*(%S*)$")
                firstname = firstname or query
                lastname = lastname or query

                local result = MySQL.query.await("SELECT p.citizenid, p.charinfo, p.metadata, md.pfp from players p LEFT JOIN mdt_data md on p.citizenid = md.cid WHERE (LOWER(JSON_UNQUOTE(JSON_EXTRACT(`charinfo`, '$.firstname'))) LIKE :firstname AND LOWER(JSON_UNQUOTE(JSON_EXTRACT(`charinfo`, '$.lastname'))) LIKE :lastname) OR LOWER(`citizenid`) LIKE :citizenid AND `jobtype` = :jobtype LIMIT 30", {
                    firstname = string.lower('%' .. firstname .. '%'),
                    lastname = string.lower('%' .. lastname .. '%'),
                    citizenid = string.lower('%' .. query .. '%'),
                    jobtype = JobType
                })

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
	local Player = QBCore.Functions.GetPlayer(src)
	if Player then
		local JobType = GetJobType(Player.PlayerData.job.name)
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
		local Player = QBCore.Functions.GetPlayer(src)
		if Player then
			local JobType = GetJobType(Player.PlayerData.job.name)
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
		local Player = QBCore.Functions.GetPlayer(src)
		if Player then
			local JobType = GetJobType(Player.PlayerData.job.name)
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
		local Player = QBCore.Functions.GetPlayer(src)
		if Player then
			local JobType = GetJobType(Player.PlayerData.job.name)
			if JobType ~= nil then
				local fullname = Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname
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

QBCore.Functions.CreateCallback('mdt:server:SearchVehicles', function(source, cb, sentData)
	if not sentData then  return cb({}) end
	local src = source
	local PlayerData = GetPlayerData(src)
	if not PermCheck(source, PlayerData) then return cb({}) end

	local src = source
	local Player = QBCore.Functions.GetPlayer(src)
	if Player then
		local JobType = GetJobType(Player.PlayerData.job.name)
		if JobType == 'police' or JobType == 'doj' then
			local vehicles = MySQL.query.await("SELECT pv.id, pv.citizenid, pv.plate, pv.vehicle, pv.mods, pv.state, p.charinfo FROM `player_vehicles` pv LEFT JOIN players p ON pv.citizenid = p.citizenid WHERE LOWER(`plate`) LIKE :query OR LOWER(`vehicle`) LIKE :query LIMIT 25", {
				query = string.lower('%'..sentData..'%')
			})

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
				local info = GetVehicleInformation(value.plate)
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
		local Player = QBCore.Functions.GetPlayer(src)
		if Player then
			local JobType = GetJobType(Player.PlayerData.job.name)
			if JobType == 'police' or JobType == 'doj' then
				local vehicle = MySQL.query.await("select pv.*, p.charinfo from player_vehicles pv LEFT JOIN players p ON pv.citizenid = p.citizenid where pv.plate = :plate LIMIT 1", { plate = string.gsub(plate, "^%s*(.-)%s*$", "%1")})
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

					local info = GetVehicleInformation(vehicle[1]['plate'])
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

RegisterNetEvent('mdt:server:saveVehicleInfo', function(dbid, plate, imageurl, notes, stolen, code5, impoundInfo, points)
	if plate then
		local src = source
		local Player = QBCore.Functions.GetPlayer(src)
		if Player then
			if GetJobType(Player.PlayerData.job.name) == 'police' then
				if dbid == nil then dbid = 0 end;
				local fullname = Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname
				TriggerEvent('mdt:server:AddLog', "A vehicle with the plate ("..plate..") has a new image ("..imageurl..") edited by "..fullname)
				if tonumber(dbid) == 0 then
					MySQL.insert('INSERT INTO `mdt_vehicleinfo` (`plate`, `information`, `image`, `code5`, `stolen`, `points`) VALUES (:plate, :information, :image, :code5, :stolen, :points)', { plate = string.gsub(plate, "^%s*(.-)%s*$", "%1"), information = notes, image = imageurl, code5 = code5, stolen = stolen, points = tonumber(points) }, function(infoResult)
						if infoResult then
							TriggerClientEvent('mdt:client:updateVehicleDbId', src, infoResult)
							TriggerEvent('mdt:server:AddLog', "A vehicle with the plate ("..plate..") was added to the vehicle information database by "..fullname)
						end
					end)
				elseif tonumber(dbid) > 0 then
					MySQL.update("UPDATE mdt_vehicleinfo SET `information`= :information, `image`= :image, `code5`= :code5, `stolen`= :stolen, `points`= :points WHERE `plate`= :plate LIMIT 1", { plate = string.gsub(plate, "^%s*(.-)%s*$", "%1"), information = notes, image = imageurl, code5 = code5, stolen = stolen, points = tonumber(points) })
				end

				if impoundInfo.impoundChanged then
					local vehicle = MySQL.single.await("SELECT p.id, p.plate, i.vehicleid AS impoundid FROM `player_vehicles` p LEFT JOIN `mdt_impound` i ON i.vehicleid = p.id WHERE plate=:plate", { plate = string.gsub(plate, "^%s*(.-)%s*$", "%1") })
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
										officer = Player.PlayerData.charinfo.firstname.. " "..Player.PlayerData.charinfo.lastname,
										number = Player.PlayerData.charinfo.phone,
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
							local result = MySQL.single.await("SELECT id, vehicle, fuel, engine, body FROM `player_vehicles` WHERE plate=:plate LIMIT 1", { plate = string.gsub(plate, "^%s*(.-)%s*$", "%1")})
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
	local Player = QBCore.Functions.GetPlayer(src)
	local JobType = GetJobType(Player.PlayerData.job.name)
	if JobType == 'police' then
		local calls = exports['ps-dispatch']:GetDispatchCalls()
		TriggerClientEvent('mdt:client:getCalls', src, calls)

	end
end)

QBCore.Functions.CreateCallback('mdt:server:SearchWeapons', function(source, cb, sentData)
	if not sentData then  return cb({}) end
	local PlayerData = GetPlayerData(source)
	if not PermCheck(source, PlayerData) then return cb({}) end

	local Player = QBCore.Functions.GetPlayer(source)
	if Player then
		local JobType = GetJobType(Player.PlayerData.job.name)
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
		local PlayerData = GetPlayerData(source)
		if not PermCheck(source, PlayerData) then return cb({}) end

		local Player = QBCore.Functions.GetPlayer(source)
		if Player then
			local JobType = GetJobType(Player.PlayerData.job.name)
			if JobType == 'police' or JobType == 'doj' then
				local fullname = Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname
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
		local Player = QBCore.Functions.GetPlayer(source)
		if Player then
			local JobType = GetJobType(Player.PlayerData.job.name)
			if JobType == 'police' or JobType == 'doj' then
				local results = MySQL.query.await('SELECT * FROM mdt_weaponinfo WHERE serial = ?', { serial })
				TriggerClientEvent('mdt:client:getWeaponData', Player.PlayerData.source, results)
			end
		end
	end
end)

RegisterNetEvent('mdt:server:getAllLogs', function()
	local src = source
	local Player = QBCore.Functions.GetPlayer(src)
	if Player then
		if Config.LogPerms[Player.PlayerData.job.name] then
			if Config.LogPerms[Player.PlayerData.job.name][Player.PlayerData.job.grade.level] then

				local JobType = GetJobType(Player.PlayerData.job.name)
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
	local Player = QBCore.Functions.GetPlayerByCitizenId(cid)
	Player.Functions.SetMetaData("callsign", newcallsign)
end)

RegisterNetEvent('mdt:server:saveIncident', function(id, title, information, tags, officers, civilians, evidence, associated, time)
	local src = source
	local Player = QBCore.Functions.GetPlayer(src)
	if Player then
		if GetJobType(Player.PlayerData.job.name) == 'police' then
			if id == 0 then
				local fullname = Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname
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
	local Player = QBCore.Functions.GetPlayer(source)
	local JobType = GetJobType(Player.PlayerData.job.name)
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
	local Player = QBCore.Functions.GetPlayer(src)
	local playerdata = {
		fullname = Player.PlayerData.charinfo.firstname.. " "..Player.PlayerData.charinfo.lastname,
		job = Player.PlayerData.job,
		cid = Player.PlayerData.citizenid,
		callsign = Player.PlayerData.metadata.callsign
	}
	local JobType = GetJobType(Player.PlayerData.job.name)
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
	local plyState = Player(source).state
	local Radio = plyState.radioChannel or 0
	local Player = QBCore.Functions.GetPlayer(src)
	local playerdata = {
		fullname = Player.PlayerData.charinfo.firstname.. " "..Player.PlayerData.charinfo.lastname,
		job = Player.PlayerData.job,
		cid = Player.PlayerData.citizenid,
		callsign = Player.PlayerData.metadata.callsign,
		radio = Radio
	}
	local JobType = GetJobType(Player.PlayerData.job.name)
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
	local Player = QBCore.Functions.GetPlayer(src)
	local JobType = GetJobType(Player.PlayerData.job.name)
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
	local Player = QBCore.Functions.GetPlayer(src)
	local playerdata = {
		fullname = Player.PlayerData.charinfo.firstname.. " "..Player.PlayerData.charinfo.lastname,
		job = Player.PlayerData.job,
		cid = Player.PlayerData.citizenid,
		callsign = Player.PlayerData.metadata.callsign
	}
	local callid = tonumber(callid)
	local JobType = GetJobType(Player.PlayerData.job.name)
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
	local Player = QBCore.Functions.GetPlayer(src)
	local callid = tonumber(callid)
	local JobType = GetJobType(Player.PlayerData.job.name)
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
	local Player = QBCore.Functions.GetPlayer(src)
	local playerdata = {
		name = Player.PlayerData.charinfo.firstname.. " "..Player.PlayerData.charinfo.lastname,
		job = Player.PlayerData.job.name,
		cid = Player.PlayerData.citizenid,
		callsign = Player.PlayerData.metadata.callsign
	}
	local callid = tonumber(callid)
	local JobType = GetJobType(Player.PlayerData.job.name)
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
	local Player = QBCore.Functions.GetPlayerByCitizenId(cid)
	local PlayerCoords = GetEntityCoords(GetPlayerPed(Player.PlayerData.source))
	TriggerClientEvent("mdt:client:setWaypoint:unit", src, PlayerCoords)
end)

-- Dispatch chat

RegisterNetEvent('mdt:server:sendMessage', function(message, time)
	if message and time then
		local src = source
		local Player = QBCore.Functions.GetPlayer(src)
		if Player then
			MySQL.scalar("SELECT pfp FROM `mdt_data` WHERE cid=:id LIMIT 1", {
				id = Player.PlayerData.citizenid -- % wildcard, needed to search for all alike results
			}, function(data)
				if data == "" then data = nil end
				local ProfilePicture = ProfPic(Player.PlayerData.charinfo.gender, data)
				local callsign = Player.PlayerData.metadata.callsign or "000"
				local Item = {
					profilepic = ProfilePicture,
					callsign = Player.PlayerData.metadata.callsign,
					cid = Player.PlayerData.citizenid,
					name = '('..callsign..') '..Player.PlayerData.charinfo.firstname.. " "..Player.PlayerData.charinfo.lastname,
					message = message,
					time = time,
					job = Player.PlayerData.job.name
				}
				dispatchMessages[#dispatchMessages+1] = Item
				TriggerClientEvent('mdt:client:dashboardMessage', -1, Item)
			end)
		end
	end
end)

RegisterNetEvent('mdt:server:refreshDispatchMsgs', function()
	local src = source
	local PlayerData = GetPlayerData(src)
	if IsJobAllowedToMDT(PlayerData.job.name) then
		TriggerClientEvent('mdt:client:dashboardMessages', src, dispatchMessages)
	end
end)

RegisterNetEvent('mdt:server:getCallResponses', function(callid)
	local src = source
	local Player = QBCore.Functions.GetPlayer(src)
	if IsPoliceOrEms(Player.PlayerData.job.name) then
		if isDispatchRunning then
			local calls = exports['ps-dispatch']:GetDispatchCalls()
			TriggerClientEvent('mdt:client:getCallResponses', src, calls[callid]['responses'], callid)
		end
	end
end)

RegisterNetEvent('mdt:server:sendCallResponse', function(message, time, callid)
	local src = source
	local Player = QBCore.Functions.GetPlayer(src)
	local name = Player.PlayerData.charinfo.firstname.. " "..Player.PlayerData.charinfo.lastname
	if IsPoliceOrEms(Player.PlayerData.job.name) then
		TriggerEvent('dispatch:sendCallResponse', src, callid, message, time, function(isGood)
			if isGood then
				TriggerClientEvent('mdt:client:sendCallResponse', -1, message, time, callid, name)
			end
		end)
	end
end)

RegisterNetEvent('mdt:server:setRadio', function(cid, newRadio)
	local src = source
	local targetPlayer = QBCore.Functions.GetPlayerByCitizenId(cid)
	local targetSource = targetPlayer.PlayerData.source
	local targetName = targetPlayer.PlayerData.charinfo.firstname .. ' ' .. targetPlayer.PlayerData.charinfo.lastname

	local radio = targetPlayer.Functions.GetItemByName("radio")
	if radio ~= nil then
		TriggerClientEvent('mdt:client:setRadio', targetSource, newRadio)
	else
		TriggerClientEvent("QBCore:Notify", src, targetName..' does not have a radio!', 'error')
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
	local Player = QBCore.Functions.GetPlayer(src)
	if Player then
		if GetJobType(Player.PlayerData.job.name) == 'police' then
			if sentInfo and type(sentInfo) == 'table' then
				local plate, linkedreport, fee, time = sentInfo['plate'], sentInfo['linkedreport'], sentInfo['fee'], sentInfo['time']
				if (plate and linkedreport and fee and time) then
				local vehicle = MySQL.query.await("SELECT id, plate FROM `player_vehicles` WHERE plate=:plate LIMIT 1", { plate = string.gsub(plate, "^%s*(.-)%s*$", "%1") })
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
								officer = Player.PlayerData.charinfo.firstname.. " "..Player.PlayerData.charinfo.lastname,
								number = Player.PlayerData.charinfo.phone,
								time = os.time() * 1000,
								src = src,
							}
							local vehicle = NetworkGetEntityFromNetworkId(sentVehicle)
							FreezeEntityPosition(vehicle, true)
							impound[#impound+1] = data

							TriggerClientEvent("police:client:ImpoundVehicle", src, true, fee)
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
	local Player = QBCore.Functions.GetPlayer(src)
	if Player then
		if GetJobType(Player.PlayerData.job.name) == 'police' then
			local result = MySQL.single.await("SELECT id, vehicle FROM `player_vehicles` WHERE plate=:plate LIMIT 1", { plate = string.gsub(plate, "^%s*(.-)%s*$", "%1")})
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
	local Player = QBCore.Functions.GetPlayer(src)
	if Player then
		if GetJobType(Player.PlayerData.job.name) == 'police' then
			local vehicle = MySQL.query.await("SELECT id, plate FROM `player_vehicles` WHERE plate=:plate LIMIT 1", { plate = string.gsub(plate, "^%s*(.-)%s*$", "%1")})
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

function GetBoloStatus(plate)

    local result = MySQL.query.await("SELECT * FROM mdt_bolos where plate = @plate", {['@plate'] = plate})
	if result and result[1] then
		local title = result[1]['title']
		local boloId = result[1]['id']
		return true, title, boloId
	end

	return false
end

function GetWarrantStatus(plate)
    local result = MySQL.query.await("SELECT p.plate, p.citizenid, m.id FROM player_vehicles p INNER JOIN mdt_convictions m ON p.citizenid = m.cid WHERE m.warrant =1 AND p.plate =?", {plate})
	if result and result[1] then
		local citizenid = result[1]['citizenid']
		local Player = QBCore.Functions.GetPlayerByCitizenId(citizenid)
		local owner = Player.PlayerData.charinfo.firstname.." "..Player.PlayerData.charinfo.lastname
		local incidentId = result[1]['id']
		return true, owner, incidentId
	end
	return false
end

function GetVehicleInformation(plate)
	local result = MySQL.query.await('SELECT * FROM mdt_vehicleinfo WHERE plate = @plate', {['@plate'] = plate})
    if result[1] then
        return result[1]
    else
        return false
    end
end

function GetVehicleOwner(plate)

	local result = MySQL.query.await('SELECT plate, citizenid, id FROM player_vehicles WHERE plate = @plate', {['@plate'] = plate})
	if result and result[1] then
		local citizenid = result[1]['citizenid']
		local Player = QBCore.Functions.GetPlayerByCitizenId(citizenid)
		local owner = Player.PlayerData.charinfo.firstname.." "..Player.PlayerData.charinfo.lastname
		return owner
	end
end

-- Returns the source for the given citizenId
QBCore.Functions.CreateCallback('mdt:server:GetPlayerSourceId', function(source, cb, targetCitizenId)
    local targetPlayer = QBCore.Functions.GetPlayerByCitizenId(targetCitizenId)
    if targetPlayer == nil then 
        TriggerClientEvent('QBCore:Notify', source, "Citizen seems Asleep / Missing", "error")
        return
    end
    local targetSource = targetPlayer.PlayerData.source

    cb(targetSource)
end)

QBCore.Functions.CreateCallback('getWeaponInfo', function(source, cb)
    local Player = QBCore.Functions.GetPlayer(source)
    local weaponInfos = {}
	if Config.InventoryForWeaponsImages == "ox_inventory" then
		local inv = exports.ox_inventory:GetInventoryItems(source)
		for _, item in pairs(inv) do
			if string.find(item.name, "WEAPON_") then
				local invImage = ("https://cfx-nui-ox_inventory/web/images/%s.png"):format(item.name)
				if invImage then
					weaponInfo = {
						serialnumber = item.metadata.serial,
						owner = Player.PlayerData.charinfo.firstname .. " " .. Player.PlayerData.charinfo.lastname,
						weaponmodel = QBCore.Shared.Items[string.lower(item.name)].label,
						weaponurl = invImage,
						notes = "Self Registered",
						weapClass = "Class 1",
					}
					break
				end
			end
		end
	else -- qb/lj
		for _, item in pairs(Player.PlayerData.items) do
			if item.type == "weapon" then
				local invImage = ("https://cfx-nui-%s/html/images/%s"):format(Config.InventoryForWeaponsImages, item.image)
				if invImage then
					local weaponInfo = {
						serialnumber = item.info.serie,
						owner = Player.PlayerData.charinfo.firstname .. " " .. Player.PlayerData.charinfo.lastname,
						weaponmodel = QBCore.Shared.Items[item.name].label,
						weaponurl = invImage,
						notes = "Self Registered",
						weapClass = "Class 1",
					}
					table.insert(weaponInfos, weaponInfo)
				end
			end
		end	
	end
    cb(weaponInfos)
end)

RegisterNetEvent('mdt:server:registerweapon', function(serial, imageurl, notes, owner, weapClass, weapModel) 
    exports['ps-mdt']:CreateWeaponInfo(serial, imageurl, notes, owner, weapClass, weapModel)
end)

local function giveCitationItem(src, citizenId, fine, incidentId)
	local Player = QBCore.Functions.GetPlayerByCitizenId(citizenId)
	local PlayerName = Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname
	local Officer = QBCore.Functions.GetPlayer(src)
	local OfficerFullName = '(' .. Officer.PlayerData.metadata.callsign .. ') ' .. Officer.PlayerData.charinfo.firstname .. ' ' .. Officer.PlayerData.charinfo.lastname

	local date = os.date("%Y-%m-%d %H:%M")
	local info = {
		citizenId = citizenId,
		fine = "$"..fine,
		date = date,
		incidentId = "#"..incidentId,
		officer = OfficerFullName,
	}
	Player.Functions.AddItem('mdtcitation', 1, false, info)
	TriggerClientEvent('QBCore:Notify', src, PlayerName.." (" ..citizenId.. ") received a citation!")
	if Config.QBManagementUse then 
		exports['qb-management']:AddMoney(Officer.PlayerData.job.name, fine) 
	end
	TriggerClientEvent('inventory:client:ItemBox', Player.PlayerData.source, QBCore.Shared.Items['mdtcitation'], "add")
	TriggerEvent('mdt:server:AddLog', "A Fine was writen by "..OfficerFullName.." and was sent to "..PlayerName..", the Amount was $".. fine ..". (ID: "..incidentId.. ")")
end

-- Removes money from the players bank and gives them a citation item
RegisterNetEvent('mdt:server:removeMoney', function(citizenId, fine, incidentId)
	local src = source
	local Player = QBCore.Functions.GetPlayerByCitizenId(citizenId)
	
	if not antiSpam then
		if Player.Functions.RemoveMoney('bank', fine, 'lspd-fine') then
			TriggerClientEvent('QBCore:Notify', Player.PlayerData.source, fine.."$ was removed from your bank!")
			giveCitationItem(src, citizenId, fine, incidentId)
		else
			TriggerClientEvent('QBCore:Notify', Player.PlayerData.source, "Something went wrong!")
		end
		antiSpam = true
		SetTimeout(60000, function()
			antiSpam = false
		end)
	else
		TriggerClientEvent('QBCore:Notify', src, "On cooldown!")
	end
end)

-- Gives the player a citation item
RegisterNetEvent('mdt:server:giveCitationItem', function(citizenId, fine, incidentId)
	local src = source
	giveCitationItem(src, citizenId, fine, incidentId)
end)

function getTopOfficers(callback)
    local result = {}
    local query = 'SELECT * FROM mdt_clocking ORDER BY total_time DESC LIMIT 25'
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
	if Config.ClockinWebhook == '' then
		print("\27[31mA webhook is missing in: Config.ClockinWebhook\27[0m")
	else
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
end

function format_time(time)
    local days = math.floor(time / 86400)
    time = time % 86400
    local hours = math.floor(time / 3600)
    time = time % 3600
    local minutes = math.floor(time / 60)
    local seconds = time % 60

    local formattedTime = ""
    if days > 0 then
        formattedTime = string.format("%d day%s ", days, days == 1 and "" or "s")
    end
    if hours > 0 then
        formattedTime = formattedTime .. string.format("%d hour%s ", hours, hours == 1 and "" or "s")
    end
    if minutes > 0 then
        formattedTime = formattedTime .. string.format("%d minute%s ", minutes, minutes == 1 and "" or "s")
    end
    if seconds > 0 then
        formattedTime = formattedTime .. string.format("%d second%s", seconds, seconds == 1 and "" or "s")
    end
    return formattedTime
end
