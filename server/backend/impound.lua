local resourceName = tostring(GetCurrentResourceName())

-- Impound a vehicle by plate
ps.registerCallback(resourceName .. ':server:impoundVehicle', function(source, payload)
    local src = source
    if not CheckAuth(src) then return { success = false, message = 'Unauthorized' } end

    payload = payload or {}
    local plate = payload.plate
    local fee = tonumber(payload.fee) or 0
    local linkedReport = tonumber(payload.reportId)

    if not plate or plate == '' then
        return { success = false, message = 'Missing plate number' }
    end

    plate = string.gsub(plate, "%s+", "")

    -- Find the vehicle
    local vehicle = MySQL.single.await('SELECT id, citizenid, plate FROM player_vehicles WHERE plate = ? LIMIT 1', { plate })
    if not vehicle then
        return { success = false, message = 'Vehicle not found' }
    end

    -- Set vehicle state to impounded (state = 2)
    MySQL.update.await('UPDATE player_vehicles SET state = 2 WHERE plate = ?', { plate })

    -- Store impound record
    local existing = MySQL.scalar.await('SELECT COUNT(*) FROM mdt_impound WHERE vehicleid = ?', { vehicle.id })
    if existing and existing > 0 then
        MySQL.update.await('UPDATE mdt_impound SET linkedreport = ?, fee = ?, time = ? WHERE vehicleid = ?', {
            linkedReport, fee, os.time(), vehicle.id
        })
    else
        MySQL.insert.await('INSERT INTO mdt_impound (vehicleid, linkedreport, fee, time) VALUES (?, ?, ?, ?)', {
            vehicle.id, linkedReport, fee, os.time()
        })
    end

    if ps.auditLog then
        local officerName = ps.getPlayerName(src) or 'Unknown'
        ps.auditLog(src, 'vehicle_impounded', 'vehicle', plate, {
            fee = fee,
            reportId = linkedReport,
            officer = officerName,
        })
    end

    return { success = true, message = 'Vehicle impounded' }
end)

-- Release a vehicle from impound
ps.registerCallback(resourceName .. ':server:releaseImpound', function(source, payload)
    local src = source
    if not CheckAuth(src) then return { success = false, message = 'Unauthorized' } end

    payload = payload or {}
    local plate = payload.plate

    if not plate or plate == '' then
        return { success = false, message = 'Missing plate number' }
    end

    plate = string.gsub(plate, "%s+", "")

    local vehicle = MySQL.single.await('SELECT id, plate FROM player_vehicles WHERE plate = ? LIMIT 1', { plate })
    if not vehicle then
        return { success = false, message = 'Vehicle not found' }
    end

    -- Get full vehicle data before releasing (for spawning)
    local fullVehicle = MySQL.single.await('SELECT id, vehicle, fuel, engine, body, plate FROM player_vehicles WHERE plate = ? LIMIT 1', { plate })

    -- Set vehicle state back to garaged (state = 1)
    MySQL.update.await('UPDATE player_vehicles SET state = 1 WHERE plate = ?', { plate })

    -- Remove impound record
    MySQL.query.await('DELETE FROM mdt_impound WHERE vehicleid = ?', { vehicle.id })

    -- Trigger client-side vehicle spawn at impound location
    if fullVehicle then
        local spawnData = {
            vehicle = fullVehicle.vehicle,
            plate = fullVehicle.plate,
            fuel = fullVehicle.fuel or 100,
            engine = fullVehicle.engine or 1000.0,
            body = fullVehicle.body or 1000.0,
            currentSelection = tonumber(payload.impoundLocation) or 1,
        }
        TriggerClientEvent(resourceName .. ':client:TakeOutImpound', src, spawnData)
    end

    if ps.auditLog then
        local officerName = ps.getPlayerName(src) or 'Unknown'
        ps.auditLog(src, 'vehicle_released', 'vehicle', plate, {
            officer = officerName,
        })
    end

    return { success = true, message = 'Vehicle released from impound' }
end)

-- Get impound status for a vehicle
ps.registerCallback(resourceName .. ':server:getImpoundStatus', function(source, payload)
    local src = source
    if not CheckAuth(src) then return { success = false } end

    payload = payload or {}
    local plate = payload.plate
    if not plate or plate == '' then
        return { success = false, message = 'Missing plate' }
    end

    plate = string.gsub(plate, "%s+", "")

    local vehicle = MySQL.single.await('SELECT id, state FROM player_vehicles WHERE plate = ? LIMIT 1', { plate })
    if not vehicle then
        return { success = false, message = 'Vehicle not found' }
    end

    local impoundInfo = nil
    if vehicle.state == 2 then
        impoundInfo = MySQL.single.await('SELECT linkedreport, fee, time FROM mdt_impound WHERE vehicleid = ? LIMIT 1', { vehicle.id })
    end

    return {
        success = true,
        impounded = vehicle.state == 2,
        impoundInfo = impoundInfo,
    }
end)
