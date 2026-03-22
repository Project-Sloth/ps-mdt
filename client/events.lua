local resourceName = tostring(GetCurrentResourceName())

local function isAuthorizedJob(job)
    if not job then return false, nil end
    if job.type == Config.PoliceJobType then return true, 'leo' end
    if job.type == Config.MedicalJobType then return true, 'ems' end
    return false, nil
end

function NUIUpdateAuthWithData(jobData)
    local job = jobData or ps.getJob()
    local authorized, jobType = isAuthorizedJob(job)
    local onDuty = job and job.onduty or false

    SendNUI('updateAuth', {
        authorized = authorized and onDuty,
        playerData = ps.getPlayerData(),
        isLEO = authorized,
        onDuty = onDuty,
        jobType = jobType or 'leo'
    })
end

local function onJobUpdate(JobInfo)
    local job = JobInfo or ps.getJob()
    ps.debug('Updated job info:', job)

    if MDTOpen then
        local authorized = isAuthorizedJob(job)

        if not authorized then
            CloseMDT()
            ps.notify('MDT closed - Access revoked', 'error')
        else
            NUIUpdateAuthWithData(job)
        end
    end
end

local function onSetDuty(duty)
    if MDTOpen then
        local job = ps.getJob()
        if job then
            job.onduty = duty
            NUIUpdateAuthWithData(job)

            local authorized = isAuthorizedJob(job)
            if not authorized then
                CloseMDT()
                ps.notify('MDT closed - Access revoked', 'error')
            end
        end
    end
end

RegisterNetEvent('QBCore:Client:SetDuty', function(duty)
    ps.debug('SetDuty event received:', duty)
    onSetDuty(duty)
end)

RegisterNetEvent('QBCore:Client:OnJobUpdate', function(JobInfo)
    ps.debug('OnJobUpdate event received:', JobInfo)
    onJobUpdate(JobInfo)
end)

RegisterNetEvent('esx:setJob', function(job)
    ps.debug('esx:setJob event received:', job)
    onJobUpdate(job)
end)

-- Send Profile Data
RegisterNetEvent(resourceName..':client:sendProfile', function(data)
    if MDTOpen then
        SendNUI('updateProfile', data)
    end
end)

-- Handle player death
if GetResourceState('baseevents') == 'started' then
    RegisterNetEvent('baseevents:onPlayerDied', function()
        if MDTOpen then
            ps.debug('Player died')
            CloseMDT()
        end
    end)
end
