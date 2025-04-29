local QBCore = exports['qb-core']:GetCoreObject()

function GetPlayerData(source)
	local Player = QBCore.Functions.GetPlayer(source)
	if Player == nil then return end -- Player not loaded in correctly
	return Player.PlayerData
end

function UnpackJob(data)
	local job = {
		name = data.name,
		label = data.label
	}
	local grade = {
		name = data.grade.name,
	}

	return job, grade
end

-- Ensure the user has permission to access the MDT
-- Checks if the user is in the allowed jobs list and if they have the required grade (if applicable)
function PermCheck(src, PlayerData)
    local allowedJob = Config.AllowedJobs[PlayerData.job.name]

    if not allowedJob or (allowedJob.minGradeRequired and PlayerData.job.grade.level < allowedJob.minGradeRequired) then
	print(("UserId: %s(%d) tried to access the MDT without authorization (server direct)"):format(GetPlayerName(src), src))
	return false
    end
    
    return true
end

function ProfPic(gender, profilepic)
	if profilepic then return profilepic end;
	if gender == "f" then return "img/female.png" end;
	return "img/male.png"
end

function IsJobAllowedToMDT(job)
	if Config.PoliceJobs[job] then
		return true
	elseif Config.AmbulanceJobs[job] then
		return true
	elseif Config.DojJobs[job] then
		return true
	else
		return false
	end
end

function GetNameFromPlayerData(PlayerData)
	return ('%s %s'):format(PlayerData.charinfo.firstname, PlayerData.charinfo.lastname)
end
