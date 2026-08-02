-- ─────────────────────────────────────────────────────────────────────────────
-- Impound
--
-- Vehicles are impounded by plate: player_vehicles.state goes to 2 and a row is
-- written to mdt_impound. Unlike the old version, releasing does NOT delete the
-- row — it flips status to 'released', so every vehicle keeps a full impound
-- history.
--
-- Releasing works from anywhere and simply puts the vehicle back into the
-- owner's garage (state 1) — they retrieve it there like any other car. No
-- spawning, no lot logistics.
-- ─────────────────────────────────────────────────────────────────────────────

local resourceName = tostring(GetCurrentResourceName())

CreateThread(function()
    -- Which department took the vehicle. Needed because the fee can be paid long after
    -- the impound, by the owner, with no officer online to ask.
    EnsureColumn('mdt_impound', 'officer_job', "`officer_job` varchar(50) DEFAULT NULL")
end)

local function impoundCfg()
    return (Config and Config.Impound) or {}
end

--- Is the impound feature switched on at all?
---@return boolean
function ImpoundEnabled()
    return impoundCfg().Enabled ~= false
end

--- Register an impound callback that refuses when the feature is off.
---
--- Wrapping the registration rather than adding a guard to each of the eleven
--- handlers below: a guard repeated eleven times is a guard forgotten once, and
--- the one that gets forgotten is a live database write reachable from a NUI
--- message. This way a new callback cannot be added without inheriting the
--- check.
---
--- The callbacks are still registered when disabled, and answer with a refusal
--- rather than not existing. A missing callback leaves the caller waiting for a
--- reply that never comes; a refusal is something the interface can act on.
---@param name string
---@param handler function
local function registerImpoundCallback(name, handler)
    ps.registerCallback(resourceName .. ':server:' .. name, function(source, payload)
        if not ImpoundEnabled() then
            -- `enabled = false` as well as `disabled = true`: the civilian view
            -- tests `enabled !== false`, so a refusal without it reads as
            -- undefined and the page carries on as though the feature were
            -- live. Empty collections for the same reason — a caller that
            -- iterates the result should find nothing, not nil.
            return {
                success  = false,
                disabled = true,
                enabled  = false,
                impounds = {},
                history  = {},
                vehicles = {},
                message  = 'Impound is disabled on this server',
            }
        end
        return handler(source, payload)
    end)
end

local function getLot(lotId)
    for _, lot in ipairs(impoundCfg().Lots or {}) do
        if lot.id == lotId then return lot end
    end
    return nil
end

local function defaultLotId()
    local lots = impoundCfg().Lots or {}
    return lots[1] and lots[1].id or nil
end

-- oxmysql hands TINYINT(1) back as a boolean, not the number 1. Comparing against
-- 1 silently inverted both fee checks: releases were blocked despite payment, and
-- the "already paid" guard never fired, so owners could be charged repeatedly.
local function isTruthy(v)
    return v == true or v == 1 or v == '1'
end

-- ── Owner e-mails ────────────────────────────────────────────────────────────
-- The owner is almost never standing next to the car when it gets impounded, and
-- may well be offline. An on-screen notification they never see is worse than
-- useless, so they get an e-mail instead — it waits for them.

local function mailOwner(citizenid, subject, body)
    if not citizenid then return end
    if not impoundCfg().NotifyOwner then return end
    if not SendCitizenMail then return end

    SendCitizenMail(
        citizenid,
        impoundCfg().MailSender or 'Vehicle Impound Unit',
        subject,
        body
    )
end

-- ── Hold periods ─────────────────────────────────────────────────────────────
-- How long the vehicle stays put before it may be released at all. Independent of
-- the fee: paying up doesn't shorten a hold, and a hold expiring doesn't waive the
-- fee. Only an officer with the override permission can cut a hold short.

local function getDuration(id)
    for _, d in ipairs(impoundCfg().Durations or {}) do
        if d.id == id then return d end
    end
    return nil
end

local function defaultDuration()
    return getDuration(impoundCfg().DefaultDuration or 'immediate')
        or (impoundCfg().Durations or {})[1]
end

--- Turn a configured duration into what actually gets stored.
--- @return string holdType, number|nil holdUntil, string|nil holdLabel
local function resolveHold(id)
    local d = getDuration(id) or defaultDuration()
    if not d then return 'immediate', nil, nil end

    if d.days == nil then
        return 'indefinite', nil, d.label
    end
    if (d.days or 0) <= 0 then
        return 'immediate', nil, d.label
    end
    return 'timed', os.time() + (d.days * 86400), d.label
end

--- Is this vehicle allowed out yet?
--- @return boolean releasable, string|nil reasonItIsNot
local function holdStatus(row)
    local t = row.hold_type or 'immediate'
    if t == 'indefinite' then
        return false, 'This vehicle is held until an officer authorises its release'
    end
    if t == 'timed' then
        local until_ = tonumber(row.hold_until) or 0
        if os.time() < until_ then
            local left = until_ - os.time()
            local days = math.floor(left / 86400)
            local hours = math.floor((left % 86400) / 3600)
            local when = days > 0
                and ('%d day(s), %d hour(s)'):format(days, hours)
                or ('%d hour(s)'):format(math.max(1, hours))
            return false, ('This vehicle is held for another %s'):format(when)
        end
    end
    return true, nil
end

-- Attach the hold state to a row on read, so the UI doesn't have to work it out.
local function decorateHold(r)
    local releasable, why = holdStatus(r)
    r.hold_releasable = releasable
    r.hold_reason = why
    if r.hold_type == 'timed' and r.hold_until then
        r.hold_seconds_left = math.max(0, (tonumber(r.hold_until) or 0) - os.time())
    else
        r.hold_seconds_left = 0
    end
end

-- ── Storage fee ──────────────────────────────────────────────────────────────
-- Derived from the impound date rather than accumulated by a timer: that makes it
-- restart-proof, impossible to drift, and correct even for rows written before
-- storage fees existed.
local function storageInfo(impoundedAt)
    local cfg = (impoundCfg().Storage) or {}
    local perDay  = cfg.PerDay or 0
    local maxDays = cfg.MaxDays or 0
    if perDay <= 0 or maxDays <= 0 or not impoundedAt then
        return 0, 0
    end

    local days = math.floor((os.time() - impoundedAt) / 86400)
    if days < 0 then days = 0 end
    local billable = math.min(days, maxDays)
    return billable * perDay, billable
end

-- Total owed = the impound fee plus however much storage has accrued.
local function totalOwed(row)
    local storage = storageInfo(row.time)
    return (row.fee or 0) + storage, storage
end

-- Recovering a vehicle closes its BOLO. 'resolved' is the status the rest of the
-- MDT uses (the enum has no 'recovered'), and the denormalised flag on
-- player_vehicles has to be cleared too or the vehicle list keeps showing a BOLO.
-- Returns true when a BOLO was actually closed.
local function clearVehicleBolo(plate)
    local closed = false
    pcall(function()
        local affected = MySQL.update.await([[
            UPDATE mdt_bolos SET status = 'resolved'
            WHERE type = 'vehicle' AND subject_id = ? AND status = 'active'
        ]], { plate })
        if affected and affected > 0 then
            closed = true
            MySQL.update.await(
                'UPDATE player_vehicles SET mdt_vehicle_boloactive = 0 WHERE plate = ?', { plate })
        end
    end)
    return closed
end

-- Plates can legitimately contain a space ("LS 12345"). This used to strip every
-- space, which turned that into "LS12345" and matched no row in player_vehicles —
-- every impound of such a vehicle failed with "Vehicle not found".
local function cleanPlate(plate)
    return NormalizePlate(plate)
end

local function officerInfo(src)
    local cid = ps.getIdentifier and ps.getIdentifier(src) or nil
    local name
    local ok, res = pcall(function()
        return (ps.getCharInfo('firstname', src) or '') .. ' ' .. (ps.getCharInfo('lastname', src) or '')
    end)
    if ok and res then name = res:gsub('^%s+', ''):gsub('%s+$', '') end
    if name == '' then name = nil end
    return cid, (name or ps.getPlayerName(src) or 'Unknown')
end

-- Fetch the active impound row for a vehicle id (or nil).
local function activeImpound(vehicleId)
    return MySQL.single.await([[
        SELECT * FROM mdt_impound
        WHERE vehicleid = ? AND status = 'active'
        ORDER BY id DESC LIMIT 1
    ]], { vehicleId })
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Impound a vehicle
-- ─────────────────────────────────────────────────────────────────────────────
-- The impound itself. Shared by the MDT callback and the on-site flow, so both
-- write exactly the same record and enforce exactly the same rules.
local function doImpound(src, payload)
    if not CheckAuth(src) then return { success = false, message = 'Unauthorized' } end
    if not CheckPermission(src, 'vehicle_impound') then
        return { success = false, message = 'Insufficient permissions' }
    end

    payload = payload or {}
    local plate = cleanPlate(payload.plate)
    if not plate then return { success = false, message = 'Missing plate number' } end

    local cfg = impoundCfg()
    local fee = math.floor(tonumber(payload.fee) or cfg.DefaultFee or 0)
    if fee < 0 then fee = 0 end
    local maxFee = cfg.MaxFee or 50000
    if fee > maxFee then
        return { success = false, message = ('Fee exceeds the maximum of $%d'):format(maxFee) }
    end

    local reason = type(payload.reason) == 'string' and payload.reason:sub(1, 100) or nil
    if not reason or reason == '' then
        return { success = false, message = 'An impound reason is required' }
    end
    local notes = type(payload.notes) == 'string' and payload.notes:sub(1, 500) or nil
    if notes == '' then notes = nil end

    local photo = type(payload.photo) == 'string' and payload.photo:sub(1, 255) or nil
    if photo == '' then photo = nil end

    local holdType, holdUntil, holdLabel = resolveHold(payload.duration)

    local lotId = payload.lot and tostring(payload.lot) or defaultLotId()
    if not getLot(lotId) then
        return { success = false, message = 'Unknown impound lot' }
    end

    local linkedReport = tonumber(payload.reportId)

    local vehicle = MySQL.single.await(
        'SELECT id, citizenid, plate, state FROM player_vehicles WHERE plate = ? LIMIT 1', { plate })
    if not vehicle then
        return { success = false, message = 'Vehicle not found' }
    end

    -- From the MDT a vehicle can only be impounded while it sits in a garage.
    -- If it's out in the world it has to be impounded on site, otherwise the DB
    -- would say "impounded" while the car is still driving around.
    if not payload.onSite and vehicle.state ~= 1 then
        return {
            success = false,
            message = 'Vehicle is not in a garage — impound it on site',
        }
    end
    if activeImpound(vehicle.id) then
        return { success = false, message = 'Vehicle is already impounded' }
    end

    local cid, officerName = officerInfo(src)

    MySQL.update.await('UPDATE player_vehicles SET state = 2 WHERE plate = ?', { plate })
    MySQL.insert.await([[
        INSERT INTO mdt_impound
            (vehicleid, status, plate, reason, notes, photo, lot, linkedreport, fee, fee_paid,
             hold_type, hold_until, hold_label,
             officer_citizenid, officer_name, officer_job, time)
        VALUES (?, 'active', ?, ?, ?, ?, ?, ?, ?, 0, ?, ?, ?, ?, ?, ?, ?)
    ]], {
        vehicle.id, plate, reason, notes, photo, lotId, linkedReport, fee,
        holdType, holdUntil, holdLabel,
        -- The department is stored WITH the impound, not looked up when the fee is paid:
        -- a citizen can settle the bill days later, with nobody from that shift online.
        cid, officerName, ps.getJobName(src), os.time(),
    })

    -- Recovering the car closes any active BOLO on it.
    local boloClosed = clearVehicleBolo(plate)

    -- Tell the owner. They had no way of knowing before this.
    local lotForMail = getLot(lotId)
    local storageCfg = impoundCfg().Storage or {}
    local body = ('Your vehicle %s has been impounded.'):format(plate)
    body = body .. ('\n\nReason: %s'):format(reason)
    body = body .. ('\nHeld at: %s'):format((lotForMail and lotForMail.label) or lotId)
    if fee > 0 then
        body = body .. ('\nRelease fee: $%d'):format(fee)
        if (storageCfg.PerDay or 0) > 0 then
            body = body .. ('\nStorage: $%d per day, up to %d days')
                :format(storageCfg.PerDay, storageCfg.MaxDays or 0)
        end
    else
        body = body .. '\nRelease fee: none'
    end
    if holdType == 'indefinite' then
        body = body .. '\n\nHold: the vehicle will not be released until law enforcement authorises it.'
    elseif holdType == 'timed' and holdUntil then
        body = body .. ('\n\nHold: the vehicle cannot be released before %s.')
            :format(os.date('%Y-%m-%d %H:%M', holdUntil))
    end
    body = body .. '\n\nSpeak to an officer to arrange release. The longer it stays with us, the more it will cost you.'
    mailOwner(vehicle.citizenid, ('Vehicle impounded — %s'):format(plate), body)

    if ps.auditLog then
        local lot = getLot(lotId)
        ps.auditLog(src, 'vehicle_impounded', 'vehicle', plate, {
            plate        = plate,
            reason       = reason,
            fee          = fee,
            lot          = lotId,
            reportId     = linkedReport,
            onSite       = payload.onSite == true,
            boloClosed   = boloClosed,
            hold         = holdLabel,
            action_label = ('Impounded %s at %s — %s (fee $%d, held: %s)'):format(
                plate, (lot and lot.label) or lotId, reason, fee, holdLabel or 'immediate'),
        })
    end

    local msg = ('%s impounded'):format(plate)
    if boloClosed then msg = msg .. ' — BOLO resolved' end
    return { success = true, message = msg, boloClosed = boloClosed }
end

registerImpoundCallback('impoundVehicle', function(source, payload)
    return doImpound(source, payload)
end)

-- ─────────────────────────────────────────────────────────────────────────────
-- Collect the release fee (bank/cash via the bridge's removeMoney).
-- ─────────────────────────────────────────────────────────────────────────────
-- ── Civilian self-service ────────────────────────────────────────────────────
-- Settling an impound bill is paperwork, not police work. Until now only an officer
-- could take the money, so a citizen whose car was impounded had to find one and ask
-- them to press Collect. These two let the owner do it themselves.
--
-- Security model, same as every other civilian callback: the citizenid comes from the
-- SESSION (ps.getIdentifier), never from the payload. A client can name any plate it
-- likes; if the vehicle isn't theirs, nothing happens. And the money always comes from
-- the caller — you cannot pay a bill out of somebody else's account.
--
-- Note what this deliberately does NOT do: it doesn't release the vehicle. Paying the
-- fee and lifting the hold are different decisions, and only one of them is the
-- citizen's to make.

local function civilianPayEnabled()
    local cfg = Config and Config.CivilianAccess
    return cfg and cfg.enabled == true and cfg.payImpounds == true
end

--- Every vehicle of MINE currently sitting in a lot, with what it costs.
registerImpoundCallback('getMyImpounds', function(source)
    local src = source
    if not civilianPayEnabled() then return { success = false, enabled = false, impounds = {} } end

    local citizenid = ps.getIdentifier(src)
    if not citizenid or citizenid == '' then
        return { success = false, message = 'Could not identify you', impounds = {} }
    end

    local rows = MySQL.query.await([[
        SELECT i.id, i.fee, i.fee_paid, i.reason, i.lot, i.notes, i.photo, i.time, i.officer_job,
               i.hold_type, i.hold_until, i.hold_label,
               v.plate, v.vehicle, v.mdt_vehicle_image AS image
        FROM mdt_impound i
        INNER JOIN player_vehicles v ON v.id = i.vehicleid
        WHERE i.status = 'active' AND v.citizenid = ?
        ORDER BY i.time DESC
    ]], { citizenid }) or {}

    local impounds = {}
    for _, r in ipairs(rows) do
        local owed, storage = totalOwed(r)
        local paid = isTruthy(r.fee_paid)

        impounds[#impounds + 1] = {
            id        = r.id,
            plate     = r.plate,
            vehicle   = VehicleDisplayName(r.vehicle),
            image     = (r.image and r.image ~= '') and r.image or nil,
            reason    = r.reason,
            -- The officer's note and the photo taken at the scene. Both were recorded
            -- and then never shown to the one person they're actually about — the owner
            -- had to ask an officer what happened to their own car.
            notes     = (r.notes and r.notes ~= '') and r.notes or nil,
            photo     = (r.photo and r.photo ~= '') and r.photo or nil,
            time      = r.time,
            -- The police UI resolves the lot id against the config it already loaded.
            -- The civilian view has no such config, so it was showing "lspd" — which is
            -- an identifier, not a place anybody could drive to.
            lot       = (getLot(r.lot) or {}).label or r.lot,
            fee       = r.fee or 0,
            storage   = storage,
            total     = owed,
            fee_paid  = paid,
            -- Shown so the citizen understands that paying doesn't get the car back
            -- on its own — the hold is a separate thing, decided by an officer.
            hold      = decorateHold(r),
        }
    end

    return { success = true, enabled = true, impounds = impounds }
end)

--- Settle the bill on one of MY vehicles.
registerImpoundCallback('payMyImpoundFee', function(source, payload)
    local src = source
    if not civilianPayEnabled() then return { success = false, message = 'Not available' } end

    local citizenid = ps.getIdentifier(src)
    if not citizenid or citizenid == '' then
        return { success = false, message = 'Could not identify you' }
    end

    payload = payload or {}
    local plate = cleanPlate(payload.plate)
    if not plate then return { success = false, message = 'Missing plate number' } end

    -- Ownership is checked in the query itself, so a forged plate simply finds nothing.
    local vehicle = MySQL.single.await(
        'SELECT id, citizenid FROM player_vehicles WHERE plate = ? AND citizenid = ? LIMIT 1',
        { plate, citizenid })
    if not vehicle then return { success = false, message = 'That is not your vehicle' } end

    local row = activeImpound(vehicle.id)
    if not row then return { success = false, message = 'That vehicle is not impounded' } end
    if isTruthy(row.fee_paid) then return { success = false, message = 'This fee is already paid' } end

    local owed, storage = totalOwed(row)
    if owed <= 0 then
        MySQL.update.await('UPDATE mdt_impound SET fee_paid = 1 WHERE id = ?', { row.id })
        return { success = true, message = 'Nothing to pay' }
    end

    -- Claim the payment BEFORE taking money. The conditional update is the lock: an
    -- officer pressing Collect at the same moment can only ever produce one charge.
    local claimed = MySQL.update.await(
        'UPDATE mdt_impound SET fee_paid = 1 WHERE id = ? AND fee_paid = 0', { row.id })
    if not claimed or claimed < 1 then
        return { success = false, message = 'This fee has just been paid' }
    end

    local account = impoundCfg().FeeAccount or 'bank'
    local removed = ps.removeMoney(src, account, owed, 'mdt-impound-fee')
    if not removed then
        -- Give the claim back, or an unpayable bill would be marked settled.
        MySQL.update.await('UPDATE mdt_impound SET fee_paid = 0 WHERE id = ?', { row.id })
        return {
            success = false,
            message = ("You don't have $%d in your %s account"):format(owed, account),
        }
    end

    -- The money goes to the department that impounded it. Read off the record, because
    -- nobody from that shift needs to be online for the owner to settle the bill.
    DepositToDepartment(row.officer_job, owed, ('Impound fee — %s'):format(plate))

    local receipt = ('$%d has been paid for the release of %s.'):format(owed, plate)
    if storage > 0 then
        receipt = receipt .. ('\n\nImpound fee: $%d\nStorage: $%d\nTotal: $%d')
            :format(row.fee or 0, storage, owed)
    end
    receipt = receipt .. '\n\nAn officer can now release your vehicle.'
    mailOwner(citizenid, ('Impound fee paid — %s'):format(plate), receipt)

    if ps.auditLog then
        ps.auditLog(src, 'vehicle_impound_fee_paid', 'vehicle', plate, {
            plate        = plate,
            fee          = row.fee,
            storage      = storage,
            total        = owed,
            self_paid    = true,
            action_label = ('Owner paid $%d for %s themselves'):format(owed, plate),
        })
    end

    return {
        success = true,
        message = ('Paid $%d for %s'):format(owed, plate),
        total   = owed,
    }
end)

registerImpoundCallback('payImpoundFee', function(source, payload)
    local src = source
    if not CheckAuth(src) then return { success = false, message = 'Unauthorized' } end
    if not CheckPermission(src, 'vehicle_impound_release') then
        return { success = false, message = 'Insufficient permissions' }
    end

    payload = payload or {}
    local plate = cleanPlate(payload.plate)
    if not plate then return { success = false, message = 'Missing plate number' } end

    local vehicle = MySQL.single.await(
        'SELECT id, citizenid FROM player_vehicles WHERE plate = ? LIMIT 1', { plate })
    if not vehicle then return { success = false, message = 'Vehicle not found' } end

    local row = activeImpound(vehicle.id)
    if not row then return { success = false, message = 'Vehicle is not impounded' } end
    if isTruthy(row.fee_paid) then return { success = false, message = 'Fee is already paid' } end

    -- What's actually owed is the impound fee plus whatever storage has accrued.
    local owed, storage = totalOwed(row)
    if owed <= 0 then
        MySQL.update.await('UPDATE mdt_impound SET fee_paid = 1 WHERE id = ?', { row.id })
        return { success = true, message = 'No fee due' }
    end

    -- The owner pays. They must be online for money to be taken.
    local owner = vehicle.citizenid and ps.getPlayerByIdentifier(vehicle.citizenid) or nil
    if not owner then
        return { success = false, message = 'Vehicle owner must be online to pay the fee' }
    end
    local ownerSrc = owner.PlayerData and owner.PlayerData.source or owner.source
    if not ownerSrc then
        return { success = false, message = 'Vehicle owner must be online to pay the fee' }
    end

    -- Collect is a payment taken at the counter, not a remote debit. Taking money out
    -- of someone's account by pressing a button from across the map is a strange kind
    -- of power, and no tow yard on earth works that way — so the owner has to be here.
    -- Anyone who isn't can settle it themselves in the civilian MDT.
    local range = tonumber(impoundCfg().CollectRange) or 0
    if range > 0 then
        local officerPed = GetPlayerPed(src)
        local ownerPed   = GetPlayerPed(ownerSrc)

        if not officerPed or officerPed == 0 or not ownerPed or ownerPed == 0 then
            return { success = false, message = 'Vehicle owner must be present to pay the fee' }
        end

        local dist = #(GetEntityCoords(officerPed) - GetEntityCoords(ownerPed))
        if dist > range then
            return {
                success = false,
                message = ('The owner must be within %dm to pay. They can also pay it themselves in their MDT.')
                    :format(math.floor(range)),
            }
        end
    end

    -- Claim the payment BEFORE taking money. The conditional update is the lock:
    -- two officers pressing Collect at once can only ever produce one charge.
    local claimed = MySQL.update.await(
        'UPDATE mdt_impound SET fee_paid = 1 WHERE id = ? AND fee_paid = 0', { row.id })
    if not claimed or claimed < 1 then
        return { success = false, message = 'Fee is already paid' }
    end

    local account = impoundCfg().FeeAccount or 'bank'
    local removed = ps.removeMoney(ownerSrc, account, owed, 'mdt-impound-fee')
    if not removed then
        MySQL.update.await('UPDATE mdt_impound SET fee_paid = 0 WHERE id = ?', { row.id })
        return { success = false, message = 'Owner could not cover the fee' }
    end

    -- Straight into the collecting department's account. It used to just evaporate.
    DepositToDepartment(row.officer_job or ps.getJobName(src), owed,
        ('Impound fee — %s'):format(plate))

    -- Money leaving an account warrants immediate feedback, so the on-screen note
    -- stays; the e-mail is the receipt they can actually go back and read.
    ps.notify(ownerSrc, ('$%d impound fee charged for %s'):format(owed, plate), 'error')

    local receipt = ('$%d has been charged for the release of %s.'):format(owed, plate)
    if storage > 0 then
        receipt = receipt .. ('\n\nImpound fee: $%d\nStorage: $%d\nTotal: $%d')
            :format(row.fee or 0, storage, owed)
    end
    receipt = receipt .. '\n\nYour vehicle can now be released.'
    mailOwner(vehicle.citizenid, ('Impound fee paid — %s'):format(plate), receipt)

    if ps.auditLog then
        ps.auditLog(src, 'vehicle_impound_fee_paid', 'vehicle', plate, {
            plate        = plate,
            fee          = row.fee,
            storage      = storage,
            total        = owed,
            action_label = storage > 0
                and ('Collected $%d for %s ($%d fee + $%d storage)'):format(owed, plate, row.fee, storage)
                or  ('Collected the $%d impound fee for %s'):format(owed, plate),
        })
    end

    return { success = true, message = ('$%d collected'):format(owed) }
end)

-- ─────────────────────────────────────────────────────────────────────────────
-- Release a vehicle: administrative, works from anywhere. The car is queued to
-- be spawned into a free spot at its lot.
-- ─────────────────────────────────────────────────────────────────────────────
registerImpoundCallback('releaseImpound', function(source, payload)
    local src = source
    if not CheckAuth(src) then return { success = false, message = 'Unauthorized' } end
    if not CheckPermission(src, 'vehicle_impound_release') then
        return { success = false, message = 'Insufficient permissions' }
    end

    payload = payload or {}
    local plate = cleanPlate(payload.plate)
    if not plate then return { success = false, message = 'Missing plate number' } end

    local vehicle = MySQL.single.await([[
        SELECT id, plate, vehicle, fuel, engine, body, citizenid
        FROM player_vehicles WHERE plate = ? LIMIT 1
    ]], { plate })
    if not vehicle then return { success = false, message = 'Vehicle not found' } end

    local row = activeImpound(vehicle.id)
    if not row then return { success = false, message = 'Vehicle is not impounded' } end

    -- Fee gate (configurable).
    local owed = totalOwed(row)
    if impoundCfg().RequireFeePaid and owed > 0 and not isTruthy(row.fee_paid) then
        return { success = false, message = ('Outstanding fee of $%d must be paid first'):format(owed) }
    end

    -- Hold gate. Cutting a hold short is a deliberate override: it needs its own
    -- permission and a written reason, and it is logged as an override rather than
    -- quietly passed off as a routine release.
    local releasable, holdWhy = holdStatus(row)
    local override = payload.override == true
    local overrideReason = type(payload.overrideReason) == 'string'
        and payload.overrideReason:sub(1, 300) or nil
    if overrideReason == '' then overrideReason = nil end

    if not releasable then
        if not override then
            return { success = false, message = holdWhy, held = true }
        end
        if not CheckPermission(src, 'vehicle_impound_override') then
            return { success = false, message = 'You are not authorised to override an impound hold' }
        end
        if not overrideReason then
            return { success = false, message = 'An override needs a reason' }
        end
    else
        -- Nothing to override; treat it as the routine release it is.
        override = false
        overrideReason = nil
    end

    local lotId = row.lot or defaultLotId()
    local lot = getLot(lotId)
    if not lot then return { success = false, message = 'Unknown impound lot' } end

    local cid, officerName = officerInfo(src)

    -- Straight back into the owner's garage (state 1). The impound row is kept
    -- for history rather than deleted.
    MySQL.update.await('UPDATE player_vehicles SET state = 1 WHERE plate = ?', { plate })
    MySQL.update.await([[
        UPDATE mdt_impound
        SET status = 'released', released_at = ?, released_by_citizenid = ?, released_by_name = ?,
            override_reason = ?
        WHERE id = ?
    ]], { os.time(), cid, officerName, overrideReason, row.id })

    -- Let the owner know it's waiting for them. By e-mail, so it also reaches them
    -- if they were offline when it was released.
    mailOwner(vehicle.citizenid,
        ('Vehicle released — %s'):format(plate),
        ('Your vehicle %s has been released from the impound lot.\n\nIt is back in your garage.')
            :format(plate))

    if ps.auditLog then
        ps.auditLog(src, override and 'vehicle_impound_override' or 'vehicle_released', 'vehicle', plate, {
            plate           = plate,
            lot             = lotId,
            override        = override,
            override_reason = overrideReason,
            hold            = row.hold_label,
            action_label = override
                and ('OVERRODE the hold on %s and released it — %s'):format(plate, overrideReason)
                or ('Released %s from %s'):format(plate, (lot and lot.label) or lotId),
        })
    end

    return {
        success = true,
        message = ('%s released — returned to the owner\'s garage'):format(plate),
    }
end)

-- ─────────────────────────────────────────────────────────────────────────────
-- On-site impound
--
-- The officer runs /impound next to a car. Everything the client claims is
-- re-checked here against the real entity: a client that lies about a net id, a
-- plate or the distance gets nothing.
-- ─────────────────────────────────────────────────────────────────────────────

-- Cleanup payouts, per officer. Kept in memory: a shift is a session, and losing
-- the counters on restart only ever costs the server money it never owed.
-- CleanupState[citizenid] = { last = os.time(), count = n }
local CleanupState = {}

local function onSiteCfg()
    return (impoundCfg().OnSite) or {}
end

-- Pay an officer. ps.addMoney doesn't exist on the bridge, so go through the
-- framework player object — the same object charges.lua already gets back from
-- ps.getPlayerByIdentifier, which is proven to work here.
local function payOfficer(src, account, amount, reason)
    if amount <= 0 then return true end

    local cid = ps.getIdentifier and ps.getIdentifier(src) or nil
    local Player = cid and ps.getPlayerByIdentifier(cid) or nil

    if Player and Player.Functions and Player.Functions.AddMoney then
        local ok = pcall(Player.Functions.AddMoney, account, amount, reason)
        if ok then return true end
    end

    -- Fall back to the core export if the bridge handed us something unexpected.
    local ok = pcall(function()
        local core = GetResourceState('qbx_core') == 'started'
            and exports['qbx_core']:GetCoreObject()
            or exports['qb-core']:GetCoreObject()
        local P = core.Functions.GetPlayer(src)
        if not P or not P.Functions or not P.Functions.AddMoney then
            error('no usable player object')
        end
        P.Functions.AddMoney(account, amount, reason)
    end)

    if not ok then
        ps.warn(('[impound] could not pay $%d to source %s'):format(amount, tostring(src)))
    end
    return ok
end

-- Resolve a client-supplied net id to a real vehicle the officer is standing at.
-- Returns entity, errorMessage.
local function resolveVehicle(src, netId)
    netId = tonumber(netId)
    if not netId then return nil, 'No vehicle selected' end

    local entity = NetworkGetEntityFromNetworkId(netId)
    if not entity or entity == 0 or not DoesEntityExist(entity) then
        return nil, 'That vehicle no longer exists'
    end
    if GetEntityType(entity) ~= 2 then -- 2 = vehicle
        return nil, 'That is not a vehicle'
    end

    -- The officer has to actually be next to it.
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil, 'Player not found' end
    local maxDist = onSiteCfg().MaxDistance or 6.0
    local dist = #(GetEntityCoords(ped) - GetEntityCoords(entity))
    if dist > (maxDist + 2.0) then -- small grace for movement during the round-trip
        return nil, 'You are too far from the vehicle'
    end

    return entity, nil
end

-- The vehicle isn't deleted the instant the record is written: it stays put for the
-- moment it takes the client to fade it out. This watchdog is the safety net for a
-- client that crashes, alt-F4s or never reports back — the world can never keep a
-- car that the database calls impounded.
local REMOVAL_GRACE = 30 -- seconds
local function scheduleRemoval(netId, seconds)
    netId = tonumber(netId)
    if not netId then return end

    CreateThread(function()
        Wait((seconds or 60) * 1000)
        local entity = NetworkGetEntityFromNetworkId(netId)
        if entity and entity ~= 0 and DoesEntityExist(entity) then
            DeleteEntity(entity)
        end
    end)
end

-- The client finished fading the vehicle out: take it out of the world for good.
RegisterNetEvent(resourceName .. ':server:removeVehicle', function(netId)
    local src = source
    if not CheckAuth(src) then return end
    netId = tonumber(netId)
    if not netId then return end

    local entity = NetworkGetEntityFromNetworkId(netId)
    if entity and entity ~= 0 and DoesEntityExist(entity) then
        DeleteEntity(entity)
    end
end)

-- Is a real player sitting in this vehicle? NPC occupants are fine; players are not.
local function hasPlayerOccupant(entity)
    for _, pid in ipairs(GetPlayers()) do
        local ped = GetPlayerPed(pid)
        if ped and ped ~= 0 and GetVehiclePedIsIn(ped, false) == entity then
            return true
        end
    end
    return false
end

-- Step 1: the client asks what it's looking at. Tells the UI whether this is an
-- owned vehicle (full impound form) or unowned traffic (quick removal).
registerImpoundCallback('inspectOnSiteVehicle', function(source, payload)
    local src = source
    if not CheckAuth(src) then return { success = false, message = 'Unauthorized' } end
    if not CheckPermission(src, 'vehicle_impound') then
        return { success = false, message = 'Insufficient permissions' }
    end

    payload = payload or {}
    local entity, err = resolveVehicle(src, payload.netId)
    if not entity then return { success = false, message = err } end

    if hasPlayerOccupant(entity) then
        return { success = false, message = 'There is somebody in that vehicle' }
    end

    local plate = cleanPlate(payload.plate)
    local owned = plate and MySQL.single.await([[
        SELECT pv.id, pv.plate, pv.vehicle, pv.state, pv.citizenid,
               pv.mdt_vehicle_stolen     AS stolen,
               pv.mdt_vehicle_boloactive AS boloactive
        FROM player_vehicles pv
        WHERE pv.plate = ? LIMIT 1
    ]], { plate }) or nil

    if not owned then
        -- Unowned traffic: no owner, no garage, no fee to collect. It just goes.
        return {
            success = true,
            owned   = false,
            plate   = plate,
            model   = payload.model,
        }
    end

    if activeImpound(owned.id) then
        return { success = false, message = 'That vehicle is already impounded' }
    end

    -- Everything the officer standing next to the car ought to know before they
    -- decide. The BOLO in particular: impounding silently resolves it, and until now
    -- there was no way to tell it was even there.
    local ownerName
    if owned.citizenid then
        local o = MySQL.single.await([[
            SELECT CONCAT(
                JSON_UNQUOTE(JSON_EXTRACT(p.charinfo, '$.firstname')), ' ',
                JSON_UNQUOTE(JSON_EXTRACT(p.charinfo, '$.lastname'))
            ) AS fullname
            FROM players p WHERE p.citizenid = ? LIMIT 1
        ]], { owned.citizenid })
        ownerName = o and o.fullname or nil
    end

    -- The bolos table is the source of truth; the column on player_vehicles is a
    -- cached flag, so either one counts.
    -- Must match clearVehicleBolo exactly: subject_id holds a citizenid, plate or
    -- serial depending on `type`, so without the type filter a BOLO on a citizen or
    -- weapon could be reported here as a vehicle BOLO — and the banner would promise
    -- to resolve something the impound never touches.
    local boloRow = MySQL.single.await([[
        SELECT id FROM mdt_bolos
        WHERE type = 'vehicle' AND subject_id = ? AND status = 'active'
        LIMIT 1
    ]], { plate })

    local prior = MySQL.single.await(
        'SELECT COUNT(*) AS n FROM mdt_impound WHERE plate = ?', { plate })

    return {
        success       = true,
        owned         = true,
        plate         = owned.plate,
        model         = owned.vehicle,
        owner         = ownerName,
        -- isTruthy, not `== 1`: oxmysql hands TINYINT(1) back as a boolean.
        stolen        = isTruthy(owned.stolen),
        bolo          = (boloRow ~= nil) or isTruthy(owned.boloactive),
        priorImpounds = (prior and tonumber(prior.n)) or 0,
    }
end)

-- Step 2a: owned vehicle — impound it properly, then remove it from the world.
registerImpoundCallback('impoundOnSite', function(source, payload)
    local src = source
    if not CheckAuth(src) then return { success = false, message = 'Unauthorized' } end
    if not CheckPermission(src, 'vehicle_impound') then
        return { success = false, message = 'Insufficient permissions' }
    end

    payload = payload or {}
    local entity, err = resolveVehicle(src, payload.netId)
    if not entity then return { success = false, message = err } end
    if hasPlayerOccupant(entity) then
        return { success = false, message = 'There is somebody in that vehicle' }
    end

    -- Same impound path as the MDT; onSite lifts the "must be garaged" rule.
    payload.onSite = true
    local result = doImpound(src, payload)
    if not result or not result.success then
        return result or { success = false, message = 'Impound failed' }
    end

    -- Give the client a moment to fade it out; this is the backstop if it never does.
    scheduleRemoval(payload.netId, REMOVAL_GRACE)

    return result
end)

-- Step 2b: unowned traffic — remove it and pay the officer for clearing the road.
registerImpoundCallback('cleanupVehicle', function(source, payload)
    local src = source
    if not CheckAuth(src) then return { success = false, message = 'Unauthorized' } end
    if not CheckPermission(src, 'vehicle_impound') then
        return { success = false, message = 'Insufficient permissions' }
    end

    payload = payload or {}
    local entity, err = resolveVehicle(src, payload.netId)
    if not entity then return { success = false, message = err } end
    if hasPlayerOccupant(entity) then
        return { success = false, message = 'There is somebody in that vehicle' }
    end

    -- Re-check ownership server-side: an owned car must never go through here,
    -- no matter what the client claims.
    local plate = cleanPlate(payload.plate)
    if plate then
        local owned = MySQL.single.await(
            'SELECT id FROM player_vehicles WHERE plate = ? LIMIT 1', { plate })
        if owned then
            return { success = false, message = 'That vehicle has an owner — impound it instead' }
        end
    end

    local cfg = onSiteCfg().Cleanup or {}
    local cid = ps.getIdentifier and ps.getIdentifier(src) or nil
    if not cid then return { success = false, message = 'Player not found' } end

    local state = CleanupState[cid] or { last = 0, count = 0 }
    local now = os.time()

    local cooldown = cfg.Cooldown or 0
    if cooldown > 0 and (now - state.last) < cooldown then
        local wait = cooldown - (now - state.last)
        return { success = false, message = ('Wait %d more second(s) before the next tow'):format(wait) }
    end

    local maxPerShift = cfg.MaxPerShift or 0
    local capped = maxPerShift > 0 and state.count >= maxPerShift

    -- The car goes either way — the cap only stops the payout, so an officer can
    -- still clear the streets after hitting the limit.
    scheduleRemoval(payload.netId, REMOVAL_GRACE)

    state.last = now
    state.count = state.count + 1
    CleanupState[cid] = state

    local reward = 0
    if not capped then
        local minR = cfg.RewardMin or 0
        local maxR = cfg.RewardMax or minR
        if maxR < minR then maxR = minR end
        reward = math.random(minR, maxR)
        if reward > 0 and not payOfficer(src, cfg.Account or 'cash', reward, 'mdt-street-cleanup') then
            reward = 0 -- couldn't pay: don't claim we did
        end
    end

    if ps.auditLog then
        ps.auditLog(src, 'vehicle_cleanup', 'vehicle', plate or 'unknown', {
            plate        = plate,
            reward       = reward,
            capped       = capped,
            action_label = capped
                and ('Removed an abandoned vehicle (%s) — shift payout limit reached'):format(plate or 'no plate')
                or  ('Removed an abandoned vehicle (%s) — earned $%d'):format(plate or 'no plate', reward),
        })
    end

    return {
        success = true,
        reward  = reward,
        capped  = capped,
        message = capped
            and 'Towed away — shift payout limit reached'
            or  ('Towed away — earned $%d'):format(reward),
    }
end)

-- Counters are per session; drop them when the officer leaves.
AddEventHandler('playerDropped', function()
    local src = source
    local cid = ps.getIdentifier and ps.getIdentifier(src) or nil
    if cid then CleanupState[cid] = nil end
end)

-- ─────────────────────────────────────────────────────────────────────────────
-- Read APIs for the MDT
-- ─────────────────────────────────────────────────────────────────────────────

-- The impound lot work list: every active impound.
registerImpoundCallback('getImpoundLot', function(source)
    local src = source
    if not CheckAuth(src) then return { vehicles = {} } end

    local rows = MySQL.query.await([[
        SELECT
            i.id, i.plate, i.reason, i.notes, i.photo, i.lot, i.fee, i.fee_paid,
            i.hold_type, i.hold_until, i.hold_label,
            i.officer_name, i.time, i.linkedreport,
            pv.vehicle AS model,
            pv.citizenid AS owner_citizenid,
            CONCAT(
                JSON_UNQUOTE(JSON_EXTRACT(p.charinfo, '$.firstname')), ' ',
                JSON_UNQUOTE(JSON_EXTRACT(p.charinfo, '$.lastname'))
            ) AS owner_name
        FROM mdt_impound i
        JOIN player_vehicles pv ON pv.id = i.vehicleid
        LEFT JOIN players p ON p.citizenid = pv.citizenid COLLATE utf8mb4_general_ci
        WHERE i.status = 'active'
        ORDER BY i.time DESC
    ]]) or {}

    -- Storage and hold state are derived, so they're attached on read.
    for _, r in ipairs(rows) do
        local storage, days = storageInfo(r.time)
        r.storage = storage
        r.days_held = days
        r.total = (r.fee or 0) + storage
        decorateHold(r)
    end

    return { vehicles = rows }
end)

-- Full impound history for one vehicle (active + past).
registerImpoundCallback('getImpoundHistory', function(source, payload)
    local src = source
    if not CheckAuth(src) then return { entries = {} } end

    payload = payload or {}
    local plate = cleanPlate(payload.plate)
    if not plate then return { entries = {} } end

    local rows = MySQL.query.await([[
        SELECT id, status, reason, notes, photo, lot, fee, fee_paid, linkedreport,
               hold_type, hold_until, hold_label, override_reason,
               officer_name, time, released_at, released_by_name
        FROM mdt_impound
        WHERE plate = ?
        ORDER BY time DESC
        LIMIT 25
    ]], { plate }) or {}

    for _, r in ipairs(rows) do
        if r.status == 'active' then
            local storage, days = storageInfo(r.time)
            r.storage = storage
            r.days_held = days
            r.total = (r.fee or 0) + storage
            decorateHold(r)
        else
            r.storage = 0
            r.total = r.fee or 0
        end
    end

    return { entries = rows }
end)

-- Reasons + lots for the impound modal.
-- Registered directly rather than through the wrapper: this is the one call the
-- interface makes to find out whether the feature exists, so a blanket refusal
-- would leave it unable to distinguish "switched off" from "request failed".
ps.registerCallback(resourceName .. ':server:getImpoundConfig', function(source)
    if not ImpoundEnabled() then
        return { enabled = false, reasons = {}, lots = {}, durations = {} }
    end
    return GetImpoundConfigPayload(source)
end)

function GetImpoundConfigPayload(source)
    if not CheckAuth(source) then return {} end
    local cfg = impoundCfg()
    local lots = {}
    for _, lot in ipairs(cfg.Lots or {}) do
        lots[#lots + 1] = { id = lot.id, label = lot.label }
    end
    return {
        reasons        = cfg.Reasons or {},
        lots           = lots,
        defaultFee     = cfg.DefaultFee or 0,
        maxFee         = cfg.MaxFee or 50000,
        requireFeePaid = cfg.RequireFeePaid == true,
        lotPageSize    = tonumber(cfg.LotPageSize) or 10,
        storage        = {
            perDay  = (cfg.Storage or {}).PerDay or 0,
            maxDays = (cfg.Storage or {}).MaxDays or 0,
        },
        durations       = cfg.Durations or {},
        defaultDuration = cfg.DefaultDuration or 'immediate',
        enabled         = true,
    }
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Self-healing: a vehicle can be set to state 2 by another resource (a garage
-- script, an older impound). Those would show as "Impounded" in the MDT with no
-- record at all. On start we adopt them so the lot view is never lying.
-- ─────────────────────────────────────────────────────────────────────────────
CreateThread(function()
    Wait(2000)
    local orphans = MySQL.query.await([[
        SELECT pv.id, pv.plate
        FROM player_vehicles pv
        LEFT JOIN mdt_impound i
            ON i.vehicleid = pv.id AND i.status = 'active'
        WHERE pv.state = 2 AND i.id IS NULL
    ]]) or {}

    if #orphans == 0 then return end

    for _, v in ipairs(orphans) do
        MySQL.insert.await([[
            INSERT INTO mdt_impound
                (vehicleid, status, plate, reason, lot, fee, fee_paid, officer_name, time)
            VALUES (?, 'active', ?, ?, ?, 0, 0, ?, ?)
        ]], { v.id, v.plate, 'Impounded outside the MDT', defaultLotId(), 'System', os.time() })
    end

    ps.debug(('[impound] adopted %d vehicle(s) that were impounded outside the MDT'):format(#orphans))
end)