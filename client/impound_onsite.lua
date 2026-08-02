-- ─────────────────────────────────────────────────────────────────────────────
-- On-site impound
--
-- /impound takes the vehicle the officer is sitting in, or the closest one.
--
-- The officer writes the vehicle up on a clipboard, then radios for a tow. Both
-- animated steps are cancellable — walk away and nothing is written. Once the
-- record exists the vehicle fades out and is removed.
--
-- Two outcomes, decided by the server:
--   * The vehicle has an owner  → the impound form opens (the same UI as the MDT)
--   * Nobody owns it (traffic)  → no form, and the officer earns a small payout
--     for clearing the road.
--
-- The client only proposes; every check that matters (distance, occupants,
-- ownership, payout limits) is re-done server-side.
-- ─────────────────────────────────────────────────────────────────────────────

local resourceName = tostring(GetCurrentResourceName())

local busy = false

local function cfg()
    return ((Config and Config.Impound) or {}).OnSite or {}
end

local function seqCfg()
    return cfg().Sequence or {}
end

-- ── Finding the vehicle ──────────────────────────────────────────────────────

local function targetVehicle()
    local ped = PlayerPedId()

    local veh = GetVehiclePedIsIn(ped, false)
    if veh ~= 0 and DoesEntityExist(veh) then return veh end

    local maxDist = cfg().MaxDistance or 6.0
    local coords = GetEntityCoords(ped)
    local best, bestDist = nil, maxDist + 0.01

    for _, v in ipairs(GetGamePool('CVehicle')) do
        if DoesEntityExist(v) then
            local d = #(GetEntityCoords(v) - coords)
            if d < bestDist then
                best, bestDist = v, d
            end
        end
    end

    return best
end

-- NPC occupants are fine — a parked car with a sleeping ped in it is still litter.
-- Only actual players block an impound.
local function hasPlayerInside(veh)
    for _, playerId in ipairs(GetActivePlayers()) do
        local ped = GetPlayerPed(playerId)
        if ped and ped ~= 0 and GetVehiclePedIsIn(ped, false) == veh then
            return true
        end
    end
    return false
end

-- ── The two animated steps ───────────────────────────────────────────────────

-- Writing the vehicle up. ox_lib handles the prop and the anim, and gives us the
-- cancel for free.
local function playNotepad()
    return lib.progressBar({
        duration  = seqCfg().NotepadMs or 4500,
        label     = 'Documenting the vehicle',
        canCancel = true,
        disable   = { move = false, car = true, combat = true },
        anim = {
            dict = 'missheistdockssetup1clipboard@base',
            clip = 'base',
            flag = 49,
        },
        prop = {
            model = GetHashKey('prop_notepad_01'),
            bone  = 18905,
            pos   = vec3(0.1, 0.02, 0.05),
            rot   = vec3(10.0, 0.0, 0.0),
        },
    })
end

-- Calling it in on the radio.
local function playRadio()
    return lib.progressBar({
        duration  = seqCfg().RadioMs or 6000,
        label     = 'Calling in a tow truck',
        canCancel = true,
        disable   = { move = false, car = true, combat = true },
        anim = {
            dict = 'amb@code_human_police_investigate@idle_a',
            clip = 'idle_b',
            flag = 49,
        },
    })
end

-- ── Removal ──────────────────────────────────────────────────────────────────

-- The vehicle is hauled off: fade it out, then the server deletes it.
local function fadeOutVehicle(veh)
    if not DoesEntityExist(veh) then return end
    local ms = cfg().FadeMs or 1200
    local steps = 17
    local wait = math.max(16, math.floor(ms / steps))

    for i = steps, 0, -1 do
        if not DoesEntityExist(veh) then break end
        SetEntityAlpha(veh, math.floor(255 * (i / steps)), false)
        Wait(wait)
    end
end

-- Radio it in, then the vehicle is taken away: it fades out and the server removes
-- it for good.
local function finishImpound(veh, netId, serverCall, payload)
    if not playRadio() then
        ps.notify('Impound cancelled', 'error')
        return
    end

    local res = ps.callback(resourceName .. ':server:' .. serverCall, payload)
    if not res or not res.success then
        ps.notify((res and res.message) or 'Impound failed', 'error')
        return
    end

    ps.notify(res.message or 'Vehicle impounded', 'success')

    if DoesEntityExist(veh) then
        fadeOutVehicle(veh)
    end

    TriggerServerEvent(resourceName .. ':server:removeVehicle', netId)
end

-- ── Entry point ──────────────────────────────────────────────────────────────

-- Set while the officer is filling in the form, so we know what to impound when
-- they submit it.
local pending = nil

local function runImpound()
    if busy then return end
    busy = true

    local veh = targetVehicle()
    if not veh then
        ps.notify('No vehicle nearby', 'error')
        busy = false
        return
    end

    if hasPlayerInside(veh) then
        ps.notify('There is somebody in that vehicle', 'error')
        busy = false
        return
    end

    local netId = NetworkGetNetworkIdFromEntity(veh)
    if not netId or netId == 0 then
        ps.notify('That vehicle cannot be impounded', 'error')
        busy = false
        return
    end

    local plate = GetVehicleNumberPlateText(veh)
    -- Trim the 8-char padding GetVehicleNumberPlateText adds, but keep spaces that are
    -- part of the plate itself ("LS 12345") — stripping those loses the vehicle.
    if plate then plate = plate:upper():gsub('^%s+', ''):gsub('%s+$', '') end
    local model = GetDisplayNameFromVehicleModel(GetEntityModel(veh))

    local res = ps.callback(resourceName .. ':server:inspectOnSiteVehicle', {
        netId = netId,
        plate = plate,
        model = model,
    })

    if not res or not res.success then
        ps.notify((res and res.message) or 'Could not inspect that vehicle', 'error')
        busy = false
        return
    end

    -- Write it up first, whichever kind of vehicle it turns out to be.
    if not playNotepad() then
        ps.notify('Impound cancelled', 'error')
        busy = false
        return
    end

    if res.owned then
        -- Owned: the officer fills in reason, fee, lot, notes, photo. The sequence
        -- continues when they submit the form.
        pending = { veh = veh, netId = netId, plate = res.plate }
        SendNUIMessage({
            action = 'showImpoundForm',
            data = {
                plate         = res.plate,
                model         = res.model,
                netId         = netId,
                owner         = res.owner,
                stolen        = res.stolen,
                bolo          = res.bolo,
                priorImpounds = res.priorImpounds,
            },
        })
        SetNuiFocus(true, true)
        busy = false
        return
    end

    -- Unowned traffic: no paperwork needed.
    finishImpound(veh, netId, 'cleanupVehicle', { netId = netId, plate = plate })
    busy = false
end

--- Whether the impound feature exists on this server at all.
---@return boolean
local function enabled()
    return not (Config and Config.Impound) or Config.Impound.Enabled ~= false
end

-- The command is not registered at all when the feature is off, rather than
-- registered and refusing. A command that exists and does nothing shows up in
-- the chat suggestion list and reads as a broken feature; one that was never
-- registered reads as a feature this server does not have.
if enabled() then
    RegisterCommand(cfg().Command or 'impound', function()
        CreateThread(runImpound)
    end, false)
end

-- So this can be hung off a target or a keybind later. Always exported, because
-- a missing export throws in the caller — a resource wired to a target option
-- should get a quiet false, not an error.
exports('impoundNearbyVehicle', function()
    if not enabled() then return false end
    CreateThread(runImpound)
    return true
end)

-- ── NUI callbacks for the standalone form ────────────────────────────────────
-- Deliberately no MDTOpen check: this form lives outside the MDT.

RegisterNUICallback('submitOnSiteImpound', function(data, cb)
    if not pending or not data then
        cb({ success = false, message = 'No vehicle selected' })
        return
    end

    -- Close the form first: the officer should watch themselves radio it in, not
    -- stare at a dialog while it happens.
    SetNuiFocus(false, false)
    cb({ success = true })

    local job = pending
    pending = nil

    data.netId = job.netId
    data.plate = job.plate
    data.onSite = true

    CreateThread(function()
        finishImpound(job.veh, job.netId, 'impoundOnSite', data)
    end)
end)

RegisterNUICallback('closeImpoundForm', function(_, cb)
    pending = nil
    SetNuiFocus(false, false)
    cb({ success = true })
end)

RegisterNUICallback('getImpoundFormConfig', function(_, cb)
    local result = ps.callback(resourceName .. ':server:getImpoundConfig', {})
    cb(result or {})
end)