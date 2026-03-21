local resourceName = tostring(GetCurrentResourceName())

function NUIUpdateAuthWithData(jobData)
    local job = jobData or ps.getJob()
    local isLEO = job and job.type == Config.PoliceJobType
    local onDuty = job and job.onduty or false

    SendNUI('updateAuth', {
        authorized = isLEO and onDuty,
        playerData = ps.getPlayerData(),
        isLEO = isLEO,
        onDuty = onDuty
    })
end

local function onJobUpdate(JobInfo)
    local job = JobInfo or ps.getJob()
    ps.debug('Updated job info:', job)

    if MDTOpen then
        local isLEO = job and job.type == Config.PoliceJobType

        if not isLEO then
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

            local isLEO = job.type == Config.PoliceJobType
            if not isLEO then
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
