local resourceName = tostring(GetCurrentResourceName())

-- AUTH -----------------------------------------------

-- Job and Duty Check
RegisterNUICallback('checkAuth', function(_, cb)
    local jobType = ps.getJobType()
    local isAuthorized = jobType == Config.PoliceJobType or jobType == Config.MedicalJobType
    local mdtJobType = jobType == Config.MedicalJobType and 'ems' or 'leo'
    local onDuty = ps.getJobDuty() or false
    local playerData = ps.getPlayerData()

    local isCivilian = false
    if not isAuthorized and Config.CivilianAccess and Config.CivilianAccess.enabled then
        isCivilian = true
    end

    cb({
        authorized = isCivilian or (isAuthorized and onDuty),
        playerData = type(playerData) == 'table' and {
            citizenid = playerData.citizenid,
            job = playerData.job,
            charinfo = playerData.charinfo,
        } or nil,
        isLEO = isAuthorized,
        onDuty = isCivilian or onDuty or false,
        jobType = isCivilian and 'civilian' or mdtJobType,
        isCivilian = isCivilian,
    })
end)

-- Separate NUI callback for fetching permissions (non-blocking)
RegisterNUICallback('getMyPermissions', function(_, cb)
    if not MDTOpen then
        cb({ permissions = {}, isBoss = false })
        return
    end

    local result = ps.callback(resourceName .. ':server:getMyPermissions')
    cb(result or { permissions = {}, isBoss = false })
end)

-- Update Auth NUI Wrapper
function NUIUpdateAuth()
    local jobType = ps.getJobType()
    local isAuthorized = jobType == Config.PoliceJobType or jobType == Config.MedicalJobType
    local mdtJobType = jobType == Config.MedicalJobType and 'ems' or 'leo'
    local playerData = ps.getPlayerData()
    SendNUI('updateAuth', {
        authorized = isAuthorized and (ps.getJobDuty() or false),
        playerData = type(playerData) == 'table' and {
            citizenid = playerData.citizenid,
            job = playerData.job,
            charinfo = playerData.charinfo,
        } or nil,
        isLEO = isAuthorized,
        onDuty = ps.getJobDuty() or false,
        jobType = mdtJobType,
    })
end

RegisterNUICallback('closeUI', function(_, cb)
    -- ps.debug('MDT closeUI triggered via NUI callback')
    PlayMDTSound('close')
    cb({})
    CloseMDT()
end)

RegisterNUICallback('signOut', function(_, cb)
    -- ps.debug('MDT signOut triggered via NUI callback')
    PlayMDTSound('close')
    cb({})
    CloseMDT()
    ps.notify('Signed out of MDT', 'success')
end)

RegisterNUICallback('toggleDuty', function(_, cb)
    -- ps.debug('MDT toggleDuty triggered via NUI callback')
    PlayMDTSound('buttonClick')
    cb({})
    TriggerServerEvent('ps_lib:server:toggleDuty')
end)

-- JOB DATA -----------------------------------------------
RegisterNUICallback('getJobData', function(_, cb)

    local jobData = ps.callback(resourceName .. ':server:getJobData')
     ps.debug('[getJobData] Triggered NUI callback on client', jobData)
    cb(jobData or {})
end)

-- REPORT STATISTICS ---------------------------------------
RegisterNUICallback('getReportStatistics', function(_, cb)
    if not MDTOpen then
        cb({ success = false, message = 'MDT is not open' })
        return
    end
    local reportStats = ps.callback(resourceName .. ':server:getReportStatistics')
    -- ps.debug('[getReportStatistics] Triggered NUI callback on client', reportStats)
    cb(reportStats)
end)



-- TIME STATISTICS -----------------------------------------
RegisterNUICallback('getTimeStatistics', function(_, cb)
    if not MDTOpen then
        cb({ success = false, message = 'MDT is not open' })
        return
    end
    local timeStats = ps.callback(resourceName .. ':server:getTimeStatistics')
    -- ps.debug('[getTimeStatistics] Triggered NUI callback on client', timeStats)
    cb(timeStats)
end)


-- ACTIVE WARRANTS -----------------------------------------
RegisterNUICallback('getActiveWarrants', function(_, cb)
    if not MDTOpen then
        cb({ success = false, message = 'MDT is not open' })
        return
    end
    local activeWarrants = ps.callback(resourceName .. ':server:getActiveWarrants')

    -- ps.debug('[getActiveWarrants] Triggered NUI callback on client',activeWarrants)
    cb(activeWarrants)
end)

-- View Warrant
RegisterNUICallback('viewWarrant', function(data, cb)
    cb({})
    TriggerServerEvent(resourceName..':server:viewWarrant', data.warrantId)
    -- ps.debug(('Viewing Warrant ID: %s'):format(data.warrantId))
end)



-- BULLETIN BOARD ----------------------------------------
RegisterNUICallback('getBulletins', function(_, cb)
    if not MDTOpen then
        cb({ success = false, message = 'MDT is not open' })
        return
    end
    local bulletins = ps.callback(resourceName .. ':server:getBulletins')
     ps.debug('[getBulletins] Triggered NUI callback on client',bulletins )
    cb(bulletins)
end)


RegisterNUICallback('createBulletin', function(data, cb)
    if not MDTOpen then cb({ success = false }) return end
    if not data or not data.content or data.content == '' then
        cb({ success = false, message = 'Content is required' })
        return
    end
    local result = ps.callback(resourceName .. ':server:createBulletin', data)
    cb(result or { success = false })
end)

RegisterNUICallback('deleteBulletin', function(data, cb)
    if not MDTOpen then cb({ success = false }) return end
    if not data or not data.id then
        cb({ success = false, message = 'Missing bulletin ID' })
        return
    end
    local result = ps.callback(resourceName .. ':server:deleteBulletin', data)
    cb(result or { success = false })
end)

-- RECENT REPORTS -------------------------------------

RegisterNUICallback('getRecentReports', function(data, cb)
    if not MDTOpen then
        cb({ success = false, message = 'MDT is not open' })
        return
    end
    local page = data and data.page or nil
    local limit = data and data.limit or nil
    local recentReports = ps.callback(resourceName .. ':server:getRecentReports', page, limit)
    -- ps.debug('[getRecentReports] Recent Reports Data:', recentReports)
    cb(recentReports)
end)

-- ACTIVE BOLOS ---------------------------------------

RegisterNUICallback('getActiveBolos', function(_, cb)
    if not MDTOpen then
        cb({ success = false, message = 'MDT is not open' })
        return
    end
    local activeBolos = ps.callback(resourceName .. ':server:getActiveBolos')
    cb(activeBolos)
end)

-- View Report
RegisterNUICallback('viewReport', function(data, cb)
    cb({})
    TriggerServerEvent(resourceName..':server:viewReport', data.reportId)
    -- ps.debug(('Viewing Report ID: %s'):format(data.reportId))
end)

-- ACTIVE UNITS ---------------------------------------

RegisterNUICallback('getActiveUnits', function(_, cb)
    if not MDTOpen then
        cb({ success = false, message = 'MDT is not open' })
        return
    end
    local activeUnits = ps.callback(resourceName .. ':server:getActiveUnits')
    -- ps.debug('[getActiveUnits] Active Units Data:', activeUnits)
    cb(activeUnits)
end)


-- DISPATCH -------------------------------------------

-- Build player data for attaching to dispatch
local function buildPlayerData()
    return {
        charinfo = {
            firstname = ps.getCharInfo('firstname'),
            lastname = ps.getCharInfo('lastname'),
        },
        metadata = {
            callsign = ps.getMetadata('callsign'),
        },
        citizenid = ps.getIdentifier(),
        job = {
            type = ps.getJobData('type'),
            name = ps.getJobData('name'),
            label = ps.getJobData('label'),
        },
    }
end

RegisterNUICallback('getRecentDispatches', function(_, cb)
    local dispatches = GetRecentDispatch()
    cb(dispatches or {})
end)

-- Real-time dispatch listener (from ps-dispatch)
RegisterNetEvent('ps-dispatch:client:notify', function(data)
    if not MDTOpen then return end
    if not data then return end
    SendNUI('updateRecentDispatches', GetRecentDispatch() or {})
end)

RegisterNUICallback('getUsageMetrics', function(_, cb)
    if not MDTOpen then
        cb({ success = false, message = 'MDT is not open' })
        return
    end

    local result = ps.callback(resourceName .. ':server:getUsageMetrics')
    cb(result or {})
end)

RegisterNUICallback("attachToDispatch", function(data, cb)
    if not MDTOpen then cb({}) return end
    local playerData = buildPlayerData()
    TriggerServerEvent('ps-dispatch:server:attach', data, playerData)
    cb(GetRecentDispatch())
    -- ps.debug('Attached to Dispatch Call: ' .. json.encode(data))
end)

RegisterNUICallback("detachFromDispatch", function(data, cb)
    if not MDTOpen then cb({}) return end
    local playerData = buildPlayerData()
    TriggerServerEvent('ps-dispatch:server:detach', data, playerData)
    Wait(100) -- wait to make sure non 1of1 servers have time to alter a server side table faster than the cb :kek:
    cb(GetRecentDispatch())
    -- ps.debug('Detached from Dispatch Call: ' .. json.encode(data))
end)

RegisterNUICallback("routeToDispatch", function(data, cb)
    local coords = data.coords or data.origin
    if not coords then
        cb('ok')
        ps.notify('No location data for this dispatch', 'error')
        return
    end
    local x = tonumber(coords.x) or tonumber(coords[1])
    local y = tonumber(coords.y) or tonumber(coords[2])
    if not x or not y then
        cb('ok')
        ps.notify('Invalid location data', 'error')
        return
    end
    SetNewWaypoint(x, y)
    cb('ok')
    ps.notify('Set Route to Dispatch Location', 'success')
end)
