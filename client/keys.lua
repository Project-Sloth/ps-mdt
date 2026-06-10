MDTOpen = false -- Track MDT state
local resourceName = tostring(GetCurrentResourceName())

-- Control management
local controlsDisabled = false
local controlCheckInterval = 0

-- Cache globals for performance
local DisableControlAction = DisableControlAction
local Wait = Wait
local CreateThread = CreateThread
local IsPedSwimming = IsPedSwimming
local SetNuiFocus = SetNuiFocus
local SetNuiFocusKeepInput = SetNuiFocusKeepInput
local SendNUI = SendNUI
local RegisterNUICallback = RegisterNUICallback

-- Permissions check ------------------------------------------

-- Check Job Authorization (returns true, false, or { isCivilian = true })
function CheckAuth()
    local result = ps.callback(resourceName..':server:checkAuth')
    if type(result) == 'table' and result.isCivilian then
        return result
    end
    return result
end

-- Controls --------------------------------------------------

-- Controls to disable
local restrictedControls = {
    -- Camera controls
    {0, 0},   -- Next Camera
    {0, 1},   -- Look Left/Right  
    {0, 2},   -- Look Up/Down
    {0, 26},  -- Look Behind

    -- Weapon controls
    {0, 16},  -- Next Weapon
    {0, 17},  -- Previous Weapon
    {0, 24},  -- Attack
    {0, 25},  -- Aim
    {0, 37},  -- Weapon Wheel
    {0, 140}, -- Melee Attack

    -- Movement controls
    {0, 21},  -- Sprint
    {0, 22},  -- Jump
    {0, 36},  -- Duck/Sneak
    {0, 44},  -- Cover
    {0, 55},  -- Dive

    -- Vehicle controls
    {0, 75},  -- Exit Vehicle
    {0, 76},  -- Handbrake
    {0, 81},  -- Next Radio
    {0, 82},  -- Previous Radio
    {0, 85},  -- Radio Wheel
    {0, 86},  -- Horn
    {0, 91},  -- Passenger Aim
    {0, 92},  -- Passenger Attack
    {0, 99},  -- Vehicle Weapon Select
    {0, 106}, -- Vehicle Override
    {0, 120}, -- Vehicle Duck

    -- Aircraft controls
    {0, 114}, -- Aircraft Attack
    {0, 115}, -- Aircraft Weapon
    {0, 121}, -- Aircraft Camera
    {0, 122}, -- Aircraft Override
    {0, 135}, -- Submarine Override

    -- UI controls
    {0, 47},  -- Detonate
    {0, 200}, -- Pause Menu
    {0, 245}, -- Chat
}

-- Control disabling loop
CreateThread(function()
    while true do
        if controlsDisabled then
            controlCheckInterval = 0
            for i = 1, #restrictedControls do
                local control = restrictedControls[i]
                DisableControlAction(control[1], control[2], true)
            end
        else
            controlCheckInterval = 150
        end
        Wait(controlCheckInterval)
    end
end)

-- Control state management
local function toggleControls(state)
    controlsDisabled = state
end

-- MDT Display ------------------------------------------------

-- Open MDT
function OpenMDT()
    -- Check auth
    local authResult = CheckAuth()

    local isCivilian = type(authResult) == 'table' and authResult.isCivilian
    if not authResult and not isCivilian then return end

    -- Don't allow if player is dead
    if ps.isDead() then
        ps.notify('You cannot open the MDT right now', 'error')
        return
    end

    -- Don't allow if swimming
    local ped = PlayerPedId()
    if IsPedSwimming(ped) then
        ps.notify('You cannot open the MDT right now', 'error')
        return
    end

    -- Don't allow if armed (skip for civilians)
    if not isCivilian and (IsPedArmed(ped, 1) or IsPedArmed(ped, 2) or IsPedArmed(ped, 4)) then
        ps.notify('You cannot open the MDT right now', 'error')
        return
    end

    -- Don't allow if viewing a camera
    if not isCivilian and exports[resourceName]:isViewingCamera() then
        ps.notify('You cannot open the MDT while viewing a camera', 'error')
        return
    end

    -- Check if MDT is already open
    if MDTOpen then
        StopTabletAnimation()
        SendNUI('setVisible', { visible = false })
        SetNuiFocus(false, false)
        SetNuiFocusKeepInput(false)
        toggleControls(false)
        MDTOpen = false
        return
    end

    MDTOpen = true

    SendNUI('setVisible', { visible = true, debugMode = Config.Debug })

    if isCivilian then
        -- Civilian mode: send auth with civilian flag
        local playerData = ps.getPlayerData()
        SendNUI('updateAuth', {
            authorized = true,
            playerData = playerData,
            isLEO = false,
            onDuty = true,
            isCivilian = true,
            jobType = 'civilian',
        })
    else
        PlayMDTSound('open')
        PlayTabletAnimation()
        NUIUpdateAuth()
        TriggerServerEvent('ps-mdt:server:trackLogin')
    end

    SetNuiFocus(true, true)
    SetNuiFocusKeepInput(false)
    toggleControls(true)
end

-- Close MDT
local closeControlsPending = false

function CloseMDT()
    if MDTOpen then
        MDTOpen = false

        StopTabletAnimation()

        SendNUI('setVisible', { visible = false })
        SetNuiFocus(false, false)

        -- Prevent ESC pause menu conflict - only spawn one delayed thread at a time
        if not closeControlsPending then
            closeControlsPending = true
            CreateThread(function()
                Wait(100)
                toggleControls(false) -- Re-enable controls
                closeControlsPending = false
            end)
        end

        ps.debug('MDT closed via CloseMDT function')
        TriggerServerEvent('ps-mdt:server:trackLogout')
    end
end

-- Nui ------------------------------------------------------

RegisterNUICallback('setTopBarHover', function(_, cb)
    cb({})
end)

-- Copy text to clipboard (FiveM NUI blocks the browser Clipboard API)
RegisterNUICallback('copyToClipboard', function(data, cb)
    if data and data.text then
        lib.setClipboard(tostring(data.text))
    end
    cb({})
end)

-- Keybinds -------------------------------------------------

-- Key to open MDT
if not Config.Keys.OpenMDT.enabled then
    ps.debug('MDT Open Keybind Disabled')
else
    ps.debug('MDT Open Keybind Enabled: ' .. Config.Keys.OpenMDT.key)
    ps.addKeybind(Config.Keys.OpenMDT.key, Config.Commands.Open.command)
end
