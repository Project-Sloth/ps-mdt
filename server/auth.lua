-- Authorisation --

local function isDojJob(jobName)
    if not jobName or not Config.DojJobs then return false end
    for _, name in ipairs(Config.DojJobs) do
        if name == jobName then return true end
    end
    return false
end

function CheckAuth(source, silent)
    ps.debug('Checking MDT Authorization')
    local jobType = ps.getJobType(source)
    local jobName = ps.getJobName(source)
    local dojCheck = isDojJob(jobName) or (Config.DojJobType and jobType == Config.DojJobType)
    if jobType ~= Config.PoliceJobType and jobType ~= Config.MedicalJobType and not dojCheck then
        ps.debug('Access Denied for ID: ' .. source .. ', Name: ' .. ps.getPlayerName(source) .. ', not an authorized job type')
        if not silent then
            ps.notify(source, 'Access Denied: Authorized Personnel Only', 'error')
        end
        return false
    else
        ps.debug('Access Granted for ID: ' .. source .. ', Name: ' .. ps.getPlayerName(source) .. ', job type: ' .. tostring(jobType))
        return true
    end
end

-- Check if a player has a specific permission (by job + grade lookup)
function CheckPermission(source, permName)
    if not source or not permName then return false end

    -- Boss always has all permissions
    if ps.isBoss and ps.isBoss(source) then return true end

    local jobData = ps.getJobData and ps.getJobData(source) or nil
    local isBoss = false
    local gradeValue = 0

    if jobData and jobData.grade then
        if type(jobData.grade) == 'table' then
            gradeValue = jobData.grade.level or jobData.grade.grade or jobData.grade.rank or jobData.grade.value or jobData.grade.id or 0
            isBoss = jobData.grade.isboss == true or jobData.grade.isBoss == true or jobData.grade.boss == true
        else
            gradeValue = jobData.grade
        end
    end

    if isBoss then return true end

    local jobName = ps.getJobName(source) or 'police'
    local gradeStr = tostring(gradeValue)

    -- Check database
    local row = MySQL.single.await('SELECT permissions FROM mdt_permission_roles WHERE job = ? AND grade = ?', { jobName, tonumber(gradeStr) })
    if row and row.permissions then
        local ok, decoded = pcall(json.decode, row.permissions)
        if ok and type(decoded) == 'table' then
            for _, p in ipairs(decoded) do
                if p == permName then return true end
            end
            return false
        end
    end

    -- Check config defaults
    local defaults = Config and Config.PermissionDefaults and Config.PermissionDefaults[jobName]
    if defaults and defaults[gradeStr] then
        for _, p in ipairs(defaults[gradeStr]) do
            if p == permName then return true end
        end
    end

    return false
end

local function upsertProfileSession(src, action)
    if not src then return end
    local citizenid = ps.getIdentifier(src)
    if not citizenid then return end

    local fullName = ps.getPlayerName(src)
    local callsign = ps.getMetadata(src, 'callsign')
    local job = ps.getJobData and ps.getJobData(src) or nil
    local jobName = job and job.name or ps.getJobName(src)
    local jobGrade = job and job.grade and job.grade.name or ps.getJobGradeName(src)

    local ok, profileId = pcall(EnsureProfileData,
        citizenid,
        fullName,
        callsign,
        callsign,
        jobGrade,
        jobName
    )

    if not ok or not profileId then
        ps.warn('Failed to upsert profile session for ' .. tostring(citizenid) .. ': ' .. tostring(profileId))
        return
    end

    if action == 'login' then
        -- Wrap all login operations in a single transaction to prevent race conditions
        local okTx, errTx = pcall(MySQL.transaction.await, {
            {
                query = [[
                    UPDATE mdt_profile_sessions
                    SET logout_at = NOW()
                    WHERE profile_id = ? AND logout_at IS NULL
                ]],
                values = { profileId }
            },
            {
                query = [[
                    INSERT INTO mdt_profile_sessions (profile_id, citizenid, source, login_at)
                    VALUES (?, ?, ?, NOW())
                ]],
                values = { profileId, citizenid, src }
            },
            {
                query = 'UPDATE mdt_profiles SET last_login_at = NOW() WHERE id = ?',
                values = { profileId }
            },
        })
        if not okTx then
            ps.warn('Failed to create login session (transaction): ' .. tostring(errTx))
        end
    elseif action == 'logout' then
        local okTx, errTx = pcall(MySQL.transaction.await, {
            {
                query = [[
                    UPDATE mdt_profile_sessions
                    SET logout_at = NOW()
                    WHERE profile_id = ? AND logout_at IS NULL
                    ORDER BY id DESC
                    LIMIT 1
                ]],
                values = { profileId }
            },
            {
                query = 'UPDATE mdt_profiles SET last_logout_at = NOW() WHERE id = ?',
                values = { profileId }
            },
        })
        if not okTx then
            ps.warn('Failed to update logout session (transaction): ' .. tostring(errTx))
        end
    end
end

-- FiveManage log helper for duty logging
local function SendDutyLog(officerName, citizenid, action, jobName)
    if not FiveManageQueueLog then return end

    FiveManageQueueLog({
        action = action == 'login' and 'mdt_clock_in' or 'mdt_clock_out',
        category = 'duty',
        message = (action == 'login' and 'Clock In' or 'Clock Out') .. ': ' .. (officerName or 'Unknown'),
        metadata = {
            officer = officerName or 'Unknown',
            citizenid = citizenid or 'N/A',
            department = jobName or 'Unknown',
            time = os.date('%Y-%m-%d %H:%M:%S')
        }
    })
end

RegisterNetEvent('ps-mdt:server:trackLogin', function()
    local src = source
    upsertProfileSession(src, 'login')
    if ps.auditLog then
        ps.auditLog(src, 'mdt_login', 'profile', ps.getIdentifier(src), {})
    end
    -- FiveManage duty log
    local officerName = ps.getPlayerName(src) or 'Unknown'
    local citizenid = ps.getIdentifier(src) or 'N/A'
    local jobName = ps.getJobName(src) or 'Unknown'
    SendDutyLog(officerName, citizenid, 'login', jobName)
end)

RegisterNetEvent('ps-mdt:server:trackLogout', function()
    local src = source
    upsertProfileSession(src, 'logout')
    if ps.auditLog then
        ps.auditLog(src, 'mdt_logout', 'profile', ps.getIdentifier(src), {})
    end
    -- FiveManage duty log
    local officerName = ps.getPlayerName(src) or 'Unknown'
    local citizenid = ps.getIdentifier(src) or 'N/A'
    local jobName = ps.getJobName(src) or 'Unknown'
    SendDutyLog(officerName, citizenid, 'logout', jobName)
end)

AddEventHandler('playerDropped', function()
    local src = source
    upsertProfileSession(src, 'logout')
end)

ps.registerCallback(tostring(GetCurrentResourceName())..':server:checkAuth', function(source)
    local civAccess = Config.CivilianAccess and Config.CivilianAccess.enabled
    local isAuthed = CheckAuth(source, civAccess)
    if isAuthed then
        return isAuthed
    end

    -- If not LEO/EMS but civilian access is enabled, return civilian flag
    if civAccess then
        return { isCivilian = true }
    end

    return false
end)

-- Get the current player's permissions based on their job + grade
ps.registerCallback(tostring(GetCurrentResourceName())..':server:getMyPermissions', function(source)
    local src = source
    if not CheckAuth(src, true) then return { permissions = {} } end

    local jobName = ps.getJobName(src) or 'police'
    local jobData = ps.getJobData and ps.getJobData(src) or nil
    local gradeValue = 0
    local isBoss = false

    if jobData and jobData.grade then
        if type(jobData.grade) == 'table' then
            gradeValue = jobData.grade.level or jobData.grade.grade or jobData.grade.rank or jobData.grade.value or jobData.grade.id or 0
            isBoss = jobData.grade.isboss == true or jobData.grade.isBoss == true or jobData.grade.boss == true
        else
            gradeValue = jobData.grade
        end
    end

    -- Boss gets all permissions
    if isBoss or (ps.isBoss and ps.isBoss(src)) then
        local allPerms = (Config and Config.ManagementPermissions) or {}
        return { permissions = allPerms, isBoss = true }
    end

    local gradeStr = tostring(gradeValue)

    -- Check database for stored permissions
    local row = MySQL.single.await('SELECT permissions FROM mdt_permission_roles WHERE job = ? AND grade = ?', { jobName, tonumber(gradeStr) })
    if row and row.permissions then
        local ok, decoded = pcall(json.decode, row.permissions)
        if ok and type(decoded) == 'table' then
            return { permissions = decoded, isBoss = false }
        end
    end

    -- Check config defaults
    local defaults = Config and Config.PermissionDefaults and Config.PermissionDefaults[jobName]
    if defaults and defaults[gradeStr] then
        return { permissions = defaults[gradeStr], isBoss = false }
    end

    -- No permissions found for this grade
    return { permissions = {}, isBoss = false }
end)
