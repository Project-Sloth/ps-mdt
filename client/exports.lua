-- Exports

-- Check if a job is an LEO job (checks against Config.PoliceJobType from the core)
local function isLEOJob(jobName)
    if not jobName then
        return ps.getJobType() == Config.PoliceJobType
    end
    if Config.PoliceJobs then
        for _, job in ipairs(Config.PoliceJobs) do
            if tostring(job) == tostring(jobName) then
                return true
            end
        end
    end
    return false
end

exports('IsLEOJob', isLEOJob)

-- Check if MDT is open
exports('IsMDTOpen', function() return MDTOpen end)

-- Open MDT with export
exports('OpenMDT', function()
    OpenMDT()
end)

-- Close MDT (delegates to full CloseMDT which handles animation, controls, logout tracking)
exports('CloseMDT', function()
    CloseMDT()
end)

-- Open civilian MDT (profile + legislation view)
exports('openCivilianMDT', function()
    if MDTOpen then return end
    MDTOpen = true
    local playerData = ps.getPlayerData()
    SendNUI('setVisible', { visible = true, debugMode = Config.Debug })
    SendNUI('updateAuth', {
        authorized = true,
        playerData = playerData,
        isLEO = false,
        onDuty = true,
        isCivilian = true,
        jobType = 'civilian',
    })
    SetNuiFocus(true, true)
    SetNuiFocusKeepInput(false)
end)