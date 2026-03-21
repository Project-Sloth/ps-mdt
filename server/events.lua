local resourceName = tostring(GetCurrentResourceName())

RegisterNetEvent(resourceName..':server:viewWarrant', function(warrantId)
    local src = source
    local Player = ps.getPlayer(src)

    if not Player then return end

    ps.debug("Server: Viewing warrant:", warrantId)
end)

RegisterNetEvent(resourceName..':server:viewBolo', function(boloId)
    local src = source
    local Player = ps.getPlayer(src)

    if not Player then return end
    if not boloId then
        ps.warn("No BOLO ID provided")
        return
    end

    local id = tonumber(boloId)
    if not id then
        ps.warn("Invalid BOLO ID type: " .. type(boloId))
        return
    end

    local reportId = MySQL.scalar.await('SELECT reportId FROM mdt_bolos WHERE id = ? LIMIT 1', { id })
    reportId = reportId and tonumber(reportId) or nil
    if not reportId then
        ps.warn("BOLO report not found for ID: " .. id)
        return
    end

    ps.info("Player ID: " .. src .. " is viewing BOLO report ID: " .. reportId)
    TriggerClientEvent('ps-mdt:client:viewReport', src, reportId)
end)

--- @description Handles the event for viewing a report in the MDT
--- @param reportId number The ID of the report to view
RegisterNetEvent(resourceName..':server:viewReport', function(reportId)
    local src = source
    local Player = ps.getPlayer(src)

    -- Validate input
    if not reportId then
        ps.warn("No report ID provided")
    return end

    if type(reportId) ~= "number" then
        ps.warn("Invalid report ID type: " .. type(reportId))
    return end

    if not Player then
        ps.warn("Player not found for report viewing: " .. reportId)
    return end

    ps.info("Player ID: " ..  src .. " is viewing report ID: " .. reportId)
    ps.debug("Server: Viewing report:", reportId)
end)

RegisterNetEvent("wk:onPlateScanned")
AddEventHandler("wk:onPlateScanned", function(cam, plate, index)
    local src = source
    local Player = ps.getPlayer(src)
    local driversLicense = ps.getMetadata(src, 'licences') and ps.getMetadata(src, 'licences').driver

    local vehicleOwner = GetVehicleOwner(plate)
    local bolo, title, boloId = GetBoloStatus(plate)
    local warrant, owner, incidentId = GetWarrantStatus(plate)

    if bolo == true then
        ps.notify(src, 'BOLO ID: '..boloId..' | Title: '..title..' | Registered Owner: '..vehicleOwner..' | Plate: '..plate, 'error', Config.WolfknightNotifyTime)
    end
    if warrant == true then
        ps.notify(src, 'WANTED - INCIDENT ID: '..incidentId..' | Registered Owner: '..owner..' | Plate: '..plate, 'error', Config.WolfknightNotifyTime)
    end

    if Config.PlateScanForDriversLicense and driversLicense == false and vehicleOwner then
        ps.notify(src, 'NO DRIVERS LICENCE | Registered Owner: '..vehicleOwner..' | Plate: '..plate, 'error', Config.WolfknightNotifyTime)
    end

    if bolo or warrant or (Config.PlateScanForDriversLicense and not driversLicense) and vehicleOwner then
        TriggerClientEvent("wk:togglePlateLock", src, cam, true, 1)
    end
end)
