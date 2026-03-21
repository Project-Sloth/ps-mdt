
local function getCertifications(citizenid)
    EnsureProfileExists(citizenid)

    local profile = MySQL.single.await('SELECT certifications FROM mdt_profiles WHERE citizenid = ?', { citizenid })
    if not profile then
        return {}
    end

    if profile.certifications and profile.certifications ~= '' then
        local ok, decoded = pcall(json.decode, profile.certifications)
        if ok and type(decoded) == 'table' then
            return decoded
        end
    end

    return {}
end

local function buildRosterFromQbx()
    local rosterList = {}
    local activeUnits = {}
    local members = {}
    local policeJobs = (Config and Config.PoliceJobs) or { 'police' }
    local qbx = exports['qbx_core']

    for _, jobName in ipairs(policeJobs) do
        local groupMembers = qbx:GetGroupMembers(jobName, 'job') or {}
        for _, member in ipairs(groupMembers) do
            if member.citizenid then
                members[member.citizenid] = true
            end
        end
    end

    for _, playerId in ipairs(qbx:GetPlayers() or {}) do
        local player = qbx:GetPlayer(playerId)
        local data = player and player.PlayerData or nil
        if data and data.job then
            local job = data.job
            if IsPoliceJob(job.name, job.type) then
                members[data.citizenid] = true
            end
        end
    end

    for _, row in ipairs(MySQL.query.await('SELECT citizenid, job FROM players', {}) or {}) do
        local job = row.job and json.decode(row.job) or {}
        if IsPoliceJob(job.name, job.type) then
            members[row.citizenid] = true
        end
    end

    for citizenid, _ in pairs(members) do
        local onlinePlayer = qbx:GetPlayerByCitizenId(citizenid)
        local player = onlinePlayer or qbx:GetOfflinePlayer(citizenid)
        if player and player.PlayerData then
            local data = player.PlayerData
            local job = data.job or {}
            local callsign = data.metadata and data.metadata.callsign or 'N/A'
            local fullname = data.charinfo and (data.charinfo.firstname .. ' ' .. data.charinfo.lastname) or 'Unknown'
            local rank = job.grade and job.grade.name or 'Officer'
            local department = job.name or 'police'
            local certifications = getCertifications(citizenid)

            rosterList[#rosterList + 1] = {
                id = #rosterList + 1,
                citizenid = citizenid,
                callsign = callsign,
                firstName = data.charinfo and data.charinfo.firstname or 'N/A',
                lastName = data.charinfo and data.charinfo.lastname or 'N/A',
                rank = rank,
                department = department,
                status = (onlinePlayer and job.onduty) and 'On Duty' or 'Off Duty',
                certifications = certifications,
                badgeNumber = callsign
            }

            if rosterList[#rosterList].status == 'On Duty' then
                activeUnits[#activeUnits + 1] = {
                    id = rosterList[#rosterList].id,
                    badgeNumber = rosterList[#rosterList].badgeNumber,
                    callsign = rosterList[#rosterList].callsign,
                    firstName = rosterList[#rosterList].firstName,
                    lastName = rosterList[#rosterList].lastName,
                }
            end
        end
    end

    return {
        roster = rosterList,
        activeUnits = activeUnits
    }
end

local function checkDuty(citizenid)
   local player = ps.getPlayerByIdentifier(citizenid)
   if not player then return 'Off Duty' end

   local src = player.source or (player.PlayerData and player.PlayerData.source)
   if not src then return 'Off Duty' end

   if IsPoliceJob(ps.getJobName(src), ps.getJobType(src)) and ps.getJobDuty(src) then
      return 'On Duty'
   end
   return 'Off Duty'
end

ps.registerCallback('ps-mdt:server:getRosterList', function(source)
    if GetResourceState('qbx_core') == 'started' and exports['qbx_core'] then
        return buildRosterFromQbx()
    end

    local rosterList = {}
    local activeUnits = {}
    local policeJobs = (Config and Config.PoliceJobs) or { 'police' }
    local jobLookup = {}
    for _, jobName in ipairs(policeJobs) do
        jobLookup[tostring(jobName)] = true
    end
    local jobType = Config and Config.PoliceJobType and tostring(Config.PoliceJobType) or nil

    local employees = {}
    if GetResourceState('ps-multijob') == 'started' and exports['ps-multijob'] then
        for _, jobName in ipairs(policeJobs) do
            local list = exports['ps-multijob']:getEmployees(jobName) or {}
            for _, employee in pairs(list) do
                if employee and employee.citizenid then
                    employees[employee.citizenid] = employee
                end
            end
        end
    end

    for _, citizen in pairs(MySQL.query.await('SELECT citizenid, charinfo, job, metadata FROM players', {}) or {}) do
        local citizenid = citizen.citizenid
        local charinfo = citizen.charinfo and json.decode(citizen.charinfo) or {}
        local job = citizen.job and json.decode(citizen.job) or {}
        local metadata = citizen.metadata and json.decode(citizen.metadata) or {}
        local jobName = job.name and tostring(job.name) or nil
        local isPolice = (jobName and jobLookup[jobName]) or (job.type and jobType and tostring(job.type) == jobType)
        if isPolice then
            local employee = employees[citizenid] or {}
            local callsign = metadata.callsign or 'N/A'
            local firstName = charinfo.firstname or 'N/A'
            local lastName = charinfo.lastname or 'N/A'
            local rank = job.grade and job.grade.name or employee.grade and ps.getSharedJobGradeData(jobName or 'police', employee.grade, 'name') or 'Officer'
            local status = checkDuty(citizenid)
            rosterList[#rosterList + 1] = {
                id = #rosterList + 1,
                citizenid = citizenid,
                callsign = callsign,
                firstName = firstName,
                lastName = lastName,
                rank = rank,
                department = jobName or employee.job or 'police',
                status = status,
                certifications = getCertifications(citizenid),
                badgeNumber = callsign
            }
            if status == 'On Duty' then
                activeUnits[#activeUnits + 1] = {
                    id = rosterList[#rosterList].id,
                    badgeNumber = rosterList[#rosterList].badgeNumber,
                    callsign = rosterList[#rosterList].callsign,
                    firstName = rosterList[#rosterList].firstName,
                    lastName = rosterList[#rosterList].lastName,
                }
            end
        end
    end
    return {
        roster = rosterList,
        activeUnits = activeUnits
    }
end)

-- Get available officer tags/certifications
ps.registerCallback('ps-mdt:server:getOfficerTags', function(source)
    local src = source
    if not CheckAuth(src) then return {} end
    local rows = MySQL.query.await([[
        SELECT id, name, color FROM mdt_tags
        WHERE type IN ('officer', 'both')
        ORDER BY name ASC
    ]])
    return rows or {}
end)

-- Update officer certifications
ps.registerCallback('ps-mdt:server:updateOfficerCertifications', function(source, payload)
    local src = source
    if not CheckAuth(src) then return { success = false, message = 'Unauthorized' } end
    if not CheckPermission(src, 'roster_manage_certifications') then
        return { success = false, message = 'No permission to manage certifications' }
    end

    payload = payload or {}
    local citizenid = payload.citizenid
    local certifications = payload.certifications

    if not citizenid or type(certifications) ~= 'table' then
        return { success = false, message = 'Invalid payload' }
    end

    EnsureProfileExists(citizenid)

    local encoded = json.encode(certifications)
    MySQL.update.await('UPDATE mdt_profiles SET certifications = ? WHERE citizenid = ?', { encoded, citizenid })

    return { success = true }
end)
