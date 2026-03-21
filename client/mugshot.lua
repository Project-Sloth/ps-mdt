-- Mugshot camera system
-- Hides MDT, shows camera overlay with zoom, captures screenshot, uploads, re-shows MDT

local resourceName = tostring(GetCurrentResourceName())

-- Camera state
local mugshotCam = nil
local mugshotActive = false
local mugshotPromise = nil
local mugshotCitizenId = nil
local mugshotCfg = Config.MugshotCamera or {}
local currentFov = mugshotCfg.DefaultFov or 50.0
local targetFov = mugshotCfg.DefaultFov or 50.0
local fovMin = mugshotCfg.FovMin or 15.0
local fovMax = mugshotCfg.FovMax or 80.0
local fovSpeed = mugshotCfg.FovSpeed or 5.0

local function restoreMDT()
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'setVisible', data = { visible = true } })
end

local function destroyCamera()
    if mugshotCam then
        RenderScriptCams(false, true, 500, true, false)
        DestroyCam(mugshotCam, false)
        mugshotCam = nil
    end
    mugshotActive = false
    SendNUIMessage({ action = 'hideMugshotCamera' })
end

local function createMugshotCamera()
    local ped = PlayerPedId()
    local pedCoords = GetEntityCoords(ped)
    local pedHeading = GetEntityHeading(ped)
    local forwardVector = GetEntityForwardVector(ped)

    -- Create camera slightly in front of and above the player's position
    local camX = pedCoords.x + forwardVector.x * 1.2
    local camY = pedCoords.y + forwardVector.y * 1.2
    local camZ = pedCoords.z + 0.5

    mugshotCam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamCoord(mugshotCam, camX, camY, camZ)
    PointCamAtCoord(mugshotCam, pedCoords.x, pedCoords.y, pedCoords.z + 0.3)

    currentFov = 50.0
    targetFov = 50.0
    SetCamFov(mugshotCam, currentFov)
    RenderScriptCams(true, true, 500, true, false)
end

local function setZoomLevel(level)
    -- level 1.0 = no zoom (fov 80), level 5.0 = max zoom (fov 15)
    local t = (level - 1.0) / 4.0 -- normalize 0-1
    targetFov = fovMax - (t * (fovMax - fovMin))
end

-- Start FOV smooth interpolation thread (only runs while mugshot is active)
local function startFovThread()
    CreateThread(function()
        while mugshotActive and mugshotCam do
            -- Smooth FOV interpolation
            if math.abs(currentFov - targetFov) > 0.1 then
                currentFov = currentFov + (targetFov - currentFov) * 0.08
                SetCamFov(mugshotCam, currentFov)
            end

            -- Mouse wheel zoom (scroll up = zoom in, scroll down = zoom out)
            DisableControlAction(0, 24, true)  -- disable attack
            DisableControlAction(0, 25, true)  -- disable aim
            DisableControlAction(0, 44, true)  -- disable cover
            DisableControlAction(0, 37, true)  -- disable select weapon

            if IsDisabledControlJustPressed(0, 241) then -- scroll up
                targetFov = math.max(targetFov - fovSpeed, fovMin)
                local zoomLevel = 1.0 + ((fovMax - targetFov) / (fovMax - fovMin)) * 4.0
                SendNUIMessage({ action = 'updateMugshotZoom', data = { level = zoomLevel } })
            end
            if IsDisabledControlJustPressed(0, 242) then -- scroll down
                targetFov = math.min(targetFov + fovSpeed, fovMax)
                local zoomLevel = 1.0 + ((fovMax - targetFov) / (fovMax - fovMin)) * 4.0
                SendNUIMessage({ action = 'updateMugshotZoom', data = { level = zoomLevel } })
            end

            Wait(0)
        end
    end)
end

--- Initiate mugshot camera mode
--- Returns imageUrl on success, nil on failure or cancel
function CaptureMugshot(citizenid)
    if not citizenid then return nil end
    if mugshotActive then return nil end

    local sbState = GetResourceState('screenshot-basic')
    if sbState ~= 'started' then
        ps.notify('screenshot-basic is not running', 'error')
        return nil
    end

    mugshotCitizenId = citizenid
    mugshotActive = true

    -- Hide MDT
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'setVisible', data = { visible = false } })
    Wait(400)

    -- Create camera
    createMugshotCamera()
    startFovThread()

    -- Show camera overlay (NUI focus for buttons)
    SetNuiFocus(true, true)
    SetNuiFocusKeepInput(true) -- allow mouse scroll while NUI is focused
    SendNUIMessage({ action = 'showMugshotCamera', data = { name = citizenid } })

    -- Wait for capture or cancel via promise
    mugshotPromise = promise.new()
    local imageUrl = Citizen.Await(mugshotPromise)
    mugshotPromise = nil

    -- Cleanup - always restore focus and destroy camera
    SetNuiFocusKeepInput(false)
    destroyCamera()
    Wait(300)
    restoreMDT()

    if imageUrl and imageUrl ~= '' and imageUrl ~= 'cancelled' then
        TriggerServerEvent(resourceName .. ':server:mugshotUpload', citizenid, { imageUrl })
        return imageUrl
    end

    return nil
end

-- NUI callback for camera actions (capture, cancel, zoom)
RegisterNUICallback('mugshotCameraAction', function(data, cb)
    if not mugshotActive then
        cb({ success = false })
        return
    end

    local action = data and data.action

    if action == 'capture' then
        cb({ success = true })
        CreateThread(function()
            -- Hide NUI overlay for clean screenshot
            SendNUIMessage({ action = 'hideMugshotCamera' })
            SetNuiFocus(false, false)
            SetNuiFocusKeepInput(false)
            Wait(100)

            -- Flash effect
            SendNUIMessage({ action = 'mugshotFlash' })
            PlaySoundFrontend(-1, "Camera_Shoot", "Phone_Soundset_Franklin", false)

            local resolved = false
            local p = promise.new()

            -- Capture screenshot as base64 (no API key on client)
            pcall(function()
                exports['screenshot-basic']:requestScreenshot(function(base64Data)
                    if resolved then return end
                    resolved = true
                    if not base64Data or base64Data == '' then
                        p:resolve(nil)
                        return
                    end
                    -- Send base64 to server for upload (API key stays server-side)
                    local result = ps.callback(resourceName .. ':server:uploadMugshotBase64', base64Data)
                    if result and result.url then
                        p:resolve(result.url)
                    else
                        p:resolve(nil)
                    end
                end, { encoding = 'png' })
            end)

            -- Timeout 15s
            SetTimeout(15000, function()
                if not resolved then
                    resolved = true
                    p:resolve(nil)
                end
            end)

            local imageUrl = Citizen.Await(p)

            if mugshotPromise then
                mugshotPromise:resolve(imageUrl)
            end
        end)
    elseif action == 'cancel' then
        cb({ success = true })
        if mugshotPromise then
            mugshotPromise:resolve('cancelled')
        end
    elseif action == 'zoom' then
        local level = tonumber(data.level) or 1.0
        setZoomLevel(level)
        cb({ success = true })
    else
        cb({ success = false })
    end
end)

-- Cleanup mugshot camera on resource stop
AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    if mugshotActive then
        SetNuiFocusKeepInput(false)
        destroyCamera()
        if mugshotPromise then
            mugshotPromise:resolve('cancelled')
            mugshotPromise = nil
        end
    end
end)
