local function getCoreObject()
    local ok, core = pcall(function()
        return exports['qb-core']:GetCoreObject()
    end)
    if ok and core then
        return core
    end

    local okQbx, qbx = pcall(function()
        return exports['qbx_core']:GetCoreObject()
    end)
    if okQbx and qbx then
        return qbx
    end

    return nil
end

local Core = getCoreObject()
local resourceName = tostring(GetCurrentResourceName())

local function formatLabel(value)
    if not value or value == '' then
        return 'Unknown'
    end
    local formatted = tostring(value)
    formatted = formatted:gsub("^%l", string.upper)
    formatted = formatted:gsub("_%l", function(s)
        return " " .. string.upper(s:sub(2))
    end)
    return formatted
end

-- ─── Insurance integration ───────────────────────────────────────────────────
-- A vehicle's STATUS (the pill shown on the profile + in the list) is no longer
-- set by hand. When Config.VehicleInsurance.enabled is true it is resolved LIVE
-- from a configurable insurance resource; when disabled every vehicle is 'valid'.
--
-- The configured export may be either callback-style or direct-return:
--   callback = true  -> exports[res]:export(plate, function(hasInsurance) end)
--   callback = false -> local hasInsurance = exports[res]:export(plate)
--
-- We always FAIL OPEN: any missing resource / export / error / timeout is treated
-- as "insured" so a broken insurance script can never wrongly flag every vehicle.

local function lookupEnabled(cfg)
    return cfg ~= nil and cfg.enabled == true
end

local function insuranceEnabled()
    return lookupEnabled(Config.VehicleInsurance)
end

local function registrationEnabled()
    return lookupEnabled(Config.VehicleRegistration)
end

local function pointsEnabled()
    -- Default ON if the config block is absent, to preserve previous behaviour.
    if Config.VehiclePoints == nil then return true end
    return Config.VehiclePoints.enabled ~= false
end

-- Generic export probe shared by insurance + registration. Returns a promise that
-- resolves to a boolean. The configured export may be callback-style or direct-return:
--   callback = true  -> exports[res]:export(plate, function(result) end)
--   callback = false -> local result = exports[res]:export(plate)
--
-- We always FAIL OPEN: any missing resource / export / error / timeout resolves to
-- `true` so a broken third-party script can never wrongly flag every vehicle.
local function startExportLookup(cfg, plate)
    cfg = cfg or {}
    local p = promise.new()
    local settled = false
    local function finish(value)
        if settled then return end
        settled = true
        -- Treat nil/anything non-false as a positive result (fail open).
        p:resolve(value ~= false)
    end

    local res = cfg.resource and exports[cfg.resource]
    if not res or res[cfg.export] == nil then
        -- Missing resource/export → fail open.
        finish(true)
        return p
    end

    -- Guard against an export that never calls back.
    SetTimeout(tonumber(cfg.timeout) or 2000, function() finish(true) end)

    local ok = pcall(function()
        if cfg.callback then
            res[cfg.export](res, plate, function(result)
                finish(result and true or false)
            end)
        else
            local result = res[cfg.export](res, plate)
            finish(result and true or false)
        end
    end)
    if not ok then
        finish(true) -- error calling the export → fail open
    end

    return p
end

-- ── Insurance ────────────────────────────────────────────────────────────────
-- Returns status, reason for a given insured flag using the configured mapping.
local function mapInsurance(hasInsurance)
    local cfg = Config.VehicleInsurance or {}
    if hasInsurance then
        return cfg.insuredStatus or 'valid', ''
    end
    return cfg.uninsuredStatus or 'uninsured', cfg.uninsuredReason or 'No active insurance'
end

-- Resolve a single plate synchronously (used by the detail view).
local function resolveInsurance(plate)
    if not insuranceEnabled() then return 'valid', '' end
    local hasInsurance = Citizen.Await(startExportLookup(Config.VehicleInsurance, plate))
    return mapInsurance(hasInsurance)
end

-- Resolve many plates in parallel (used by the list). Returns a map of
-- UPPER(plate) -> { status = ..., reason = ... }. Empty map = treat all as valid.
local function resolveInsuranceBatch(plates)
    local out = {}
    if not insuranceEnabled() then return out end

    local cfg = Config.VehicleInsurance or {}
    if cfg.resolveInList == false then return out end

    -- Kick every lookup off first so they run concurrently, THEN await them.
    local pending = {}
    for _, plate in ipairs(plates) do
        pending[#pending + 1] = { plate = plate, p = startExportLookup(cfg, plate) }
    end
    for _, item in ipairs(pending) do
        local hasInsurance = Citizen.Await(item.p)
        local status, reason = mapInsurance(hasInsurance)
        out[string.upper(item.plate)] = { status = status, reason = reason }
    end
    return out
end

-- ── Registration ─────────────────────────────────────────────────────────────
-- Registration is a simple boolean (registered / not) resolved from a configurable
-- export, mirroring the insurance integration. The same FAIL OPEN guarantees apply,
-- so a missing/broken registration script always reports vehicles as registered.

-- Returns registered(bool), reason(string) for a given lookup result.
local function mapRegistration(hasRegistration)
    local cfg = Config.VehicleRegistration or {}
    if hasRegistration then
        return true, ''
    end
    return false, cfg.unregisteredReason or 'No active registration'
end

-- Resolve a single plate synchronously (used by the detail view).
local function resolveRegistration(plate)
    if not registrationEnabled() then return true, '' end
    local hasRegistration = Citizen.Await(startExportLookup(Config.VehicleRegistration, plate))
    return mapRegistration(hasRegistration)
end

-- Resolve many plates in parallel (used by the list). Returns a map of
-- UPPER(plate) -> { registered = ..., reason = ... }. Empty map = treat all as registered.
local function resolveRegistrationBatch(plates)
    local out = {}
    if not registrationEnabled() then return out end

    local cfg = Config.VehicleRegistration or {}
    if cfg.resolveInList == false then return out end

    local pending = {}
    for _, plate in ipairs(plates) do
        pending[#pending + 1] = { plate = plate, p = startExportLookup(cfg, plate) }
    end
    for _, item in ipairs(pending) do
        local hasRegistration = Citizen.Await(item.p)
        local registered, reason = mapRegistration(hasRegistration)
        out[string.upper(item.plate)] = { registered = registered, reason = reason }
    end
    return out
end

local function getVehicleShared(model)
    if not Core or not Core.Shared or not Core.Shared.Vehicles then
        return nil
    end
    return Core.Shared.Vehicles[model]
end

local function buildVehicleFlags(stolen, hasActiveBolo, status)
    local flags = {}
    if hasActiveBolo then
        table.insert(flags, 'Bolo')
    end
    if stolen then
        table.insert(flags, 'Stolen')
    end
    if status and status ~= 'valid' then
        table.insert(flags, ('Status: %s'):format(formatLabel(status)))
    end
    return flags
end

local function countSetItems(set)
    if not set then
        return 0
    end
    local count = 0
    for _ in pairs(set) do
        count = count + 1
    end
    return count
end

ps.registerCallback(resourceName .. ':server:GetVehicles', function(source)
    local startTime = os.clock()
    local src = source
    if not CheckAuth(src) then return end

    local vehList = MySQL.query.await([[
        SELECT
            pv.id,
            pv.plate,
            pv.vehicle,
            pv.citizenid,
            pv.mdt_vehicle_information AS information,
            pv.mdt_vehicle_points AS points,
            pv.mdt_vehicle_status AS status,
            pv.mdt_vehicle_stolen AS stolen,
            pv.mdt_vehicle_boloactive AS boloactive,
            pv.mdt_vehicle_image AS image,
            pv.state AS core_state
        FROM player_vehicles pv
    ]])

    local boloRows = MySQL.query.await('SELECT * FROM mdt_bolos WHERE type = ? AND status = ?', {'vehicle', 'active'})
    local reportIdsByPlate = {}
    local activeBoloByPlate = {}
    local bolos = {}

    for _, bolo in pairs(boloRows) do
        local plate = bolo.subject_id and string.upper(tostring(bolo.subject_id)) or nil
        if plate then
            reportIdsByPlate[plate] = reportIdsByPlate[plate] or {}
            if bolo.reportId then
                reportIdsByPlate[plate][tostring(bolo.reportId)] = true
            end
            if bolo.status == 'active' then
                activeBoloByPlate[plate] = true
            end
        end
        table.insert(bolos, {
            id = bolo.id,
            reportId = bolo.reportId and tostring(bolo.reportId) or 'N/A',
            name = bolo.subject_name or 'Unknown Vehicle',
            type = bolo.type,
            notes = bolo.notes or '',
            status = bolo.status,
            plate = bolo.subject_id or 'Unknown',
            image = bolo.image or 'https://docs.fivem.net/vehicles/elegy.webp',
        })
    end

    -- Resolve insurance + registration for every plate up-front (runs concurrently).
    local platesForInsurance = {}
    for _, v in ipairs(vehList) do
        platesForInsurance[#platesForInsurance + 1] = v.plate and string.upper(v.plate) or 'UNKNOWN'
    end
    local insuranceByPlate = resolveInsuranceBatch(platesForInsurance)
    local registrationByPlate = resolveRegistrationBatch(platesForInsurance)

    local vehicles = {}
    for _, v in ipairs(vehList) do
        local vehicleData = getVehicleShared(v.vehicle)
        local plate = v.plate and string.upper(v.plate) or 'UNKNOWN'
        local reportCount = countSetItems(reportIdsByPlate[plate])
        local hasActiveBolo = activeBoloByPlate[plate] == true or v.boloactive == 1
        -- Status/reason come from insurance (or default to 'valid' when disabled).
        local ins = insuranceByPlate[plate]
        local statusName = ins and ins.status or 'valid'
        local statusReason = ins and ins.reason or ''
        -- Registration is a separate boolean (defaults to registered when disabled).
        local reg = registrationByPlate[plate]
        local registered = reg == nil or reg.registered ~= false
        local registrationReason = reg and reg.reason or ''
        local flags = buildVehicleFlags(v.stolen == 1, hasActiveBolo, statusName)

        table.insert(vehicles, {
            id = v.id,
            model = v.vehicle,
            label = vehicleData and vehicleData.name or 'Unknown Vehicle',
            plate = plate,
            owner = ps.getPlayerNameByIdentifier(v.citizenid) or 'Unknown',
            class = formatLabel(vehicleData and vehicleData.category or 'Unknown'),
            type = formatLabel(vehicleData and vehicleData.type or 'Unknown'),
            flags = flags,
            image = (v.image and v.image ~= '' and v.image) or ('https://docs.fivem.net/vehicles/' .. v.vehicle .. '.webp'),
            seenIn = reportCount,
            points = tonumber(v.points) or 0,
            status = statusName,
            reason = statusReason,
            registered = registered,
            registrationReason = registrationReason,
            core_state = tonumber(v.core_state) or 0,
        })
    end

    local endTime = os.clock()
    local elapsedTime = (endTime - startTime) * 1000
    ps.debug(string.format("getVehicles callback executed in %.2f ms", elapsedTime))

    if vehicles[1] then
        ps.debug('[getVehicles] Sample vehicle data structure:', vehicles[1])
    end
    if bolos[1] then
        ps.debug('[getVehicles] Sample bolo data structure:', bolos[1])
    end

    return {
        vehicles = vehicles,
        bolos = bolos,
        features = {
            points = pointsEnabled(),
            insurance = insuranceEnabled(),
            registration = registrationEnabled(),
        },
        canEditPoints = CheckPermission(src, 'vehicles_edit_dmv'),
    }
end)

ps.registerCallback(resourceName .. ':server:UpdateVehicle', function(source, payload)
    local src = source
    if not CheckAuth(src) then return { success = false, message = 'Unauthorized' } end

    payload = payload or {}
    local plate = payload.plate
    if not plate or plate == '' then
        return { success = false, message = 'Missing plate' }
    end

    local ownerRow = MySQL.single.await('SELECT citizenid FROM player_vehicles WHERE plate = ? LIMIT 1', { plate })
    if not ownerRow or not ownerRow.citizenid then
        return { success = false, message = 'Vehicle not found' }
    end

    local updates = {}
    local values = {}

    if payload.information ~= nil then
        updates[#updates + 1] = 'mdt_vehicle_information = ?'
        values[#values + 1] = payload.information
    end

    if payload.image ~= nil then
        updates[#updates + 1] = 'mdt_vehicle_image = ?'
        values[#values + 1] = payload.image
    end

    -- Points are the only "DMV" field officers can still set, and only when the
    -- feature is enabled and the officer holds the edit permission.
    local points = nil
    if payload.points ~= nil then
        if not pointsEnabled() then
            return { success = false, message = 'Points are disabled' }
        end
        if not CheckPermission(src, 'vehicles_edit_dmv') then
            return { success = false, message = 'Insufficient permissions' }
        end
        points = tonumber(payload.points)
        if not points then
            return { success = false, message = 'Invalid points value' }
        end
        if points < 0 then points = 0 end
        if points > 1000 then points = 1000 end -- sane upper bound
        points = math.floor(points)
        updates[#updates + 1] = 'mdt_vehicle_points = ?'
        values[#values + 1] = points
    end

    if #updates == 0 then
        return { success = true }
    end

    values[#values + 1] = plate

    MySQL.update.await(('UPDATE player_vehicles SET %s WHERE plate = ?'):format(table.concat(updates, ', ')), values)

    if ps.auditLog then
        ps.auditLog(src, 'vehicle_updated', 'vehicle', plate, {
            plate = plate,
            points = points,
            information = payload.information,
        })
    end

    return { success = true }
end)

ps.registerCallback(resourceName .. ':server:GetVehicle', function(source, plate)
    local src = source
    if not CheckAuth(src) then return end

    if not plate or plate == '' then
        return { success = false, message = 'Missing plate' }
    end

    local vehicleRow = MySQL.query.await([[
        SELECT
            pv.id,
            pv.plate,
            pv.vehicle,
            pv.citizenid,
            pv.mdt_vehicle_information AS information,
            pv.mdt_vehicle_points AS points,
            pv.mdt_vehicle_status AS status,
            pv.mdt_vehicle_stolen AS stolen,
            pv.mdt_vehicle_boloactive AS boloactive,
            pv.mdt_vehicle_image AS image,
            pv.state AS core_state
        FROM player_vehicles pv
        WHERE pv.plate = ?
        LIMIT 1
    ]], { plate })

    if not vehicleRow or not vehicleRow[1] then
        return { success = false, message = 'Vehicle not found' }
    end

    local row = vehicleRow[1]
    local vehicleData = getVehicleShared(row.vehicle)
    local plateUpper = row.plate and string.upper(row.plate) or 'UNKNOWN'

    local boloRows = MySQL.query.await('SELECT * FROM mdt_bolos WHERE type = ? AND subject_id = ?', { 'vehicle', plate })
    local reportIdSet = {}
    local bolos = {}
    local hasActiveBolo = false
    for _, bolo in pairs(boloRows) do
        if bolo.reportId then
            reportIdSet[tostring(bolo.reportId)] = true
        end
        if bolo.status == 'active' then
            hasActiveBolo = true
        end
        table.insert(bolos, {
            id = bolo.id,
            reportId = bolo.reportId and tostring(bolo.reportId) or 'N/A',
            notes = bolo.notes or '',
            status = bolo.status,
            type = bolo.type,
        })
    end

    local reportCount = countSetItems(reportIdSet)
    local statusName, statusReason = resolveInsurance(plateUpper)
    local registered, registrationReason = resolveRegistration(plateUpper)
    local flags = buildVehicleFlags(row.stolen == 1, hasActiveBolo or row.boloactive == 1, statusName)

    return {
        success = true,
        features = {
            points = pointsEnabled(),
            insurance = insuranceEnabled(),
            registration = registrationEnabled(),
        },
        canEditPoints = CheckPermission(src, 'vehicles_edit_dmv'),
        vehicle = {
            id = row.id,
            model = row.vehicle,
            label = vehicleData and vehicleData.name or 'Unknown Vehicle',
            brand = vehicleData and vehicleData.brand or nil,
            plate = plateUpper,
            owner = ps.getPlayerNameByIdentifier(row.citizenid) or 'Unknown',
            class = formatLabel(vehicleData and vehicleData.category or 'Unknown'),
            type = formatLabel(vehicleData and vehicleData.type or 'Unknown'),
            image = (row.image and row.image ~= '' and row.image) or ('https://docs.fivem.net/vehicles/' .. row.vehicle .. '.webp'),
            information = row.information or '',
            points = tonumber(row.points) or 0,
            status = statusName,
            reason = statusReason,
            registered = registered,
            registrationReason = registrationReason,
            core_state = tonumber(row.core_state) or 0,
            stolen = row.stolen == 1,
            boloactive = row.boloactive == 1,
            flags = flags,
            seenIn = reportCount,
            bolos = bolos,
        }
    }
end)