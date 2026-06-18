local resourceName = tostring(GetCurrentResourceName())

-- Camera viewing state
local currentCamera = nil
local isViewingCamera = false
local hiddenCameraEntity = nil
local currentCameraData = nil

-- Dashcam view state
local dashcamRear = false      -- false = front camera, true = rear camera
local dashcamSpeedKmh = 0      -- current speed of the viewed vehicle (km/h)
-- Live transform pushed by the server (used when the vehicle isn't streamed to
-- the viewer, e.g. the unit is far away). nil until the first push arrives.
local dashcamFeed = nil        -- { coords, heading, speed, vehicleNetId, t }
local dashcamRenderCoords = nil -- smoothed camera position when using the feed

-- Forward declarations
local startCameraControlThread
local updateCameraControls

-- Camera control settings (from Config with fallbacks)
local camCfg = Config.CameraViewer or {}
local cameraOptions = {
    rotationSpeed = camCfg.RotationSpeed or 0.15,
    zoomClamp = {min = camCfg.ZoomClamp and camCfg.ZoomClamp.min or 0.25, max = camCfg.ZoomClamp and camCfg.ZoomClamp.max or 10.0},
    startingZoom = camCfg.StartingZoom or 3.0,
    zoomStep = camCfg.ZoomStep or 0.1,
}

-- Camera placement system
local CameraPlacement = {}
local cameraModelsCache = nil

-- Camera Viewing ---------------------------------------

-- Stop camera view
local function stopCameraView(notifyServer)
    ps.debug('Stopping camera view, notifyServer:', notifyServer)

    if isViewingCamera and currentCamera then
        DoScreenFadeOut(250)
        while not IsScreenFadedOut() do
            Wait(0)
        end

        SetCamActive(currentCamera, false)
        RenderScriptCams(false, false, 0, true, true)
        DestroyCam(currentCamera, false)
        currentCamera = nil
        isViewingCamera = false

        if hiddenCameraEntity and DoesEntityExist(hiddenCameraEntity) then
            ps.debug('Restoring visibility of camera entity:', hiddenCameraEntity)
            SetEntityVisible(hiddenCameraEntity, true, false)
            hiddenCameraEntity = nil
        end

        ClearTimecycleModifier()

        ps.debug('Clearing focus area')
        StopTabletAnimation()
        ClearFocus()

        DoScreenFadeIn(250)

        if notifyServer then
            if currentCameraData and currentCameraData.isBodycam then
                local bodycamId = currentCameraData.targetSource and tostring(currentCameraData.targetSource) or 'unknown'
                ps.debug('Notifying server to deactivate bodycam:', bodycamId)
                TriggerServerEvent(resourceName .. ':server:deactivateBodycam', bodycamId)
            elseif currentCameraData and currentCameraData.isDashcam then
                local dashcamId = currentCameraData.dashcamId or ('dashcam:' .. tostring(currentCameraData.targetSource or 'unknown'))
                ps.debug('Notifying server to deactivate dashcam:', dashcamId)
                TriggerServerEvent(resourceName .. ':server:deactivateDashcam', dashcamId)
            else
                ps.debug('Notifying server to deactivate regular camera')
                TriggerServerEvent(resourceName .. ':server:deactivateCamera', 'current')
            end
        end

        currentCameraData = nil

        ps.debug('Camera view stopped')
    else
        ps.debug('No active camera view to stop')
    end
end

-- Start camera view
RegisterNetEvent(resourceName..':client:startCameraView', function(cameraData)
    ps.debug('Starting camera view with data type:', type(cameraData))
    ps.debug('Starting camera view with data:', json.encode(cameraData or {}))

    -- Validate
    if not cameraData or type(cameraData) ~= 'table' then
        ps.error('Invalid camera data received - type: ' .. type(cameraData))
        return
    end

    if not cameraData.coords or not cameraData.rotation then
        ps.error('Camera data missing coords or rotation')
        return
    end

    ps.debug('Camera coords:', cameraData.coords)
    ps.debug('Camera rotation:', cameraData.rotation)

    -- Stop any existing camera view first
    if isViewingCamera and currentCamera then
        ps.debug('Stopping existing camera view first...')
        stopCameraView(true)
    end

    DoScreenFadeOut(250)
    while not IsScreenFadedOut() do
        Wait(0)
    end

    -- Set focus area to the camera coordinates to ensure the area is streamed.
    -- Use the feed position if the camera has a decoupled feed, otherwise the prop.
    local focusCoords = cameraData.feedCoords or cameraData.coords
    ps.debug('Setting focus area to camera coordinates:', focusCoords.x, focusCoords.y, focusCoords.z)
    SetFocusPosAndVel(focusCoords.x, focusCoords.y, focusCoords.z, 0, 0, 0)
    -- Wait a moment for the focus area to take effect
    Wait(100)

    -- Create a camera that views from the entity coords
    local cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    ps.debug('CreateCam result:', cam, 'type:', type(cam))

    -- Hide the camera entity if it exists to avoid obscuring the view
    if cameraData.networkId then
        local cameraEntity = NetworkGetEntityFromNetworkId(cameraData.networkId)
        if cameraEntity and DoesEntityExist(cameraEntity) then
            ps.debug('Hiding camera entity:', cameraEntity, 'with network ID:', cameraData.networkId)
            SetEntityVisible(cameraEntity, false, false)
            hiddenCameraEntity = cameraEntity
        else
            ps.debug('Camera entity not found or does not exist for network ID:', cameraData.networkId)
        end
    end

    if cam and cam ~= 0 then
        -- Prefer the decoupled feed transform (set by the feed placer). It is
        -- exactly what the operator aimed, so no heading offset is applied.
        -- Cameras without a feed fall back to the prop transform: player-placed
        -- props look opposite to their heading so they get the (configurable)
        -- offset; virtual cams and bodycams do not.
        local hasFeed = cameraData.feedCoords ~= nil and cameraData.feedRotation ~= nil
        local coords, rotation, fov

        if hasFeed then
            coords = cameraData.feedCoords
            rotation = cameraData.feedRotation
            fov = cameraData.feedFov or 50.0
            ps.debug('Using decoupled feed transform for camera view')
            SetCamCoord(cam, coords.x, coords.y, coords.z)
            SetCamRot(cam, rotation.x, rotation.y, rotation.z, 2)
            SetCamFov(cam, fov)
        else
            coords = cameraData.coords
            rotation = cameraData.rotation
            local needsOffset = cameraData.spawnsModel == true and not cameraData.isBodycam and not cameraData.isDashcam
            local headingOffset = needsOffset and (camCfg.HeadingOffset or 180.0) or 0.0
            ps.debug('Using prop transform (no feed) for camera view')
            SetCamCoord(cam, coords.x, coords.y, coords.z)
            SetCamRot(cam, rotation.x, rotation.y, (rotation.z + headingOffset) % 360.0, 2)
            SetCamFov(cam, 50.0)
        end

        ps.debug('Camera properties set - Position:', tostring(coords), 'Rotation:', tostring(rotation))

        -- debug shit
        -- local camCoords = GetCamCoord(cam)
        -- local camRot = GetCamRot(cam, 2)
        -- ps.debug('Verified camera coords:', tostring(camCoords))
        -- ps.debug('Verified camera rotation:', tostring(camRot))

        SetCamActive(cam, true)
        ps.debug('Camera activated')
        RenderScriptCams(true, false, 0, true, true)
        currentCamera = cam
        isViewingCamera = true
        currentCameraData = cameraData

        SetTimecycleModifier('scanline_cam_cheap')
        SetTimecycleModifierStrength(1.0)

        DoScreenFadeIn(250)
        startCameraControlThread()

        ps.debug('Camera view activated at coordinates:', tostring(coords))
    else
        ps.error('Failed to create camera - CreateCam returned:', tostring(cam))

        if hiddenCameraEntity and DoesEntityExist(hiddenCameraEntity) then
            ps.debug('Restoring visibility of camera entity due to camera creation failure:', hiddenCameraEntity)
            SetEntityVisible(hiddenCameraEntity, true, false)
            hiddenCameraEntity = nil
        end

        ClearFocus() -- Clear focus area since we're exiting
        DoScreenFadeIn(250)
    end
end)

-- Stop camera view (from server)
RegisterNetEvent(resourceName..':client:stopCameraView', function()
    stopCameraView(false)
end)

-- Camera controls help text
local function ShowCameraHelpNotification(text)
    AddTextEntry('CameraHelpMsg', text)
    BeginTextCommandDisplayHelp('CameraHelpMsg')
    EndTextCommandDisplayHelp(0, false, true, -1)
end

-- CCTV overlay HUD ------------------------------------

local function drawHudText(text, x, y, scale, r, g, b, a, align)
    SetTextFont(4)
    SetTextScale(scale, scale)
    SetTextColour(r, g, b, a)
    SetTextDropShadow()
    SetTextOutline()
    if align == 'right' then
        SetTextJustification(2)
        SetTextWrap(0.0, x)
    elseif align == 'center' then
        SetTextCentre(true)
    end
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(x, y)
end

-- Real server time for the overlay. The FiveM client has no `os` library and we
-- don't want the client's local clock, so we sync the server's epoch + timezone
-- offset once (via callback) and tick locally with GetGameTimer(). No per-frame
-- or per-second network traffic. Reformatted at most once per second.
local srvBaseEpoch = nil   -- server UTC epoch at last sync
local srvOffset = 0        -- server local timezone offset (seconds)
local srvSyncTimer = 0     -- GetGameTimer() value at sync
local overlayTimeStr = ''
local overlayTimeLastSec = -1

local function syncServerTime()
    local t = ps.callback(resourceName .. ':server:getServerTime')
    if t and t.epoch then
        srvBaseEpoch = t.epoch
        srvOffset = t.offset or 0
        srvSyncTimer = GetGameTimer()
        overlayTimeLastSec = -1
    end
end

-- Convert an epoch (already shifted to the desired timezone) to a date string.
-- Uses Howard Hinnant's days->civil algorithm so no os/date library is needed.
local function epochToString(epoch)
    local days = math.floor(epoch / 86400)
    local secs = epoch % 86400
    local hour = math.floor(secs / 3600)
    local minute = math.floor((secs % 3600) / 60)
    local second = secs % 60

    local z = days + 719468
    local era = math.floor((z >= 0 and z or (z - 146096)) / 146097)
    local doe = z - era * 146097
    local yoe = math.floor((doe - math.floor(doe / 1460) + math.floor(doe / 36524) - math.floor(doe / 146096)) / 365)
    local y = yoe + era * 400
    local doy = doe - (365 * yoe + math.floor(yoe / 4) - math.floor(yoe / 100))
    local mp = math.floor((5 * doy + 2) / 153)
    local d = doy - math.floor((153 * mp + 2) / 5) + 1
    local m = (mp < 10) and (mp + 3) or (mp - 9)
    if m <= 2 then y = y + 1 end

    return ('%04d-%02d-%02d  %02d:%02d:%02d'):format(y, m, d, hour, minute, second)
end

local function getOverlayTime()
    if not srvBaseEpoch then return '' end
    local cur = srvBaseEpoch + math.floor((GetGameTimer() - srvSyncTimer) / 1000)
    if cur ~= overlayTimeLastSec then
        overlayTimeLastSec = cur
        overlayTimeStr = epochToString(cur + srvOffset)
    end
    return overlayTimeStr
end

-- Draws a simple CCTV overlay while a camera is being viewed.
local function drawCameraOverlay()
    if not isViewingCamera or not currentCamera then return end
    local ov = (camCfg and camCfg.Overlay) or {}
    if ov.enabled == false then return end

    local data = currentCameraData or {}
    local label
    local subline = nil
    if data.isBodycam == true then
        label = 'BODYCAM - ' .. tostring(data.officerName or data.playerName or 'Unknown')
    elseif data.isDashcam == true then
        label = 'DASHCAM - ' .. tostring(data.officerName or 'Unit')
        local parts = {}
        if data.callsign and data.callsign ~= '' then parts[#parts + 1] = 'CS ' .. tostring(data.callsign) end
        if data.plate and data.plate ~= '' then parts[#parts + 1] = tostring(data.plate) end
        parts[#parts + 1] = ('%d km/h'):format(math.floor(dashcamSpeedKmh + 0.5))
        parts[#parts + 1] = dashcamRear and 'REAR' or 'FRONT'
        subline = table.concat(parts, '   ')
    else
        label = tostring(data.camLabel or 'CCTV')
    end

    -- Top contrast bar
    DrawRect(0.5, 0.035, 1.0, 0.06, 0, 0, 0, 140)

    -- REC dot + camera name (top left)
    local showDot = (ov.recBlink == false) or ((GetGameTimer() % 1200) < 700)
    if showDot then
        DrawRect(0.036, 0.037, 0.007, 0.012, 200, 35, 35, 255)
    end
    drawHudText(label, 0.05, 0.022, 0.55, 255, 255, 255, 255)
    if subline then
        drawHudText(subline, 0.05, 0.05, 0.34, 190, 190, 190, 220)
    end

    -- Real date + time (top right)
    if ov.showTimestamp ~= false then
        drawHudText(getOverlayTime(), 0.965, 0.024, 0.45, 220, 220, 220, 230, 'right')
    end

    -- Subtle exit/controls hint (bottom left)
    local hint = (data.isDashcam == true) and '[ESC] Exit     [E] Front/Rear' or '[ESC] Exit'
    drawHudText(hint, 0.036, 0.95, 0.34, 200, 200, 200, 170)
end

-- Camera controls
-- Dashcam offsets come strictly from Config.Dashcam.Positions.models. There is
-- no default: an unconfigured model returns nil and the view won't position
-- (the server already blocks viewing unconfigured vehicles).
local function buildDashcamOffset(chosen)
    if not chosen then return nil end
    local side = chosen.side or 0.0
    local forward = chosen.forward or 2.0
    local height = chosen.height or 0.7
    local pitch = chosen.pitch or 0.0
    return {
        side = side,
        forward = forward,
        height = height,
        pitch = pitch,
        rearSide = chosen.rearSide or side,
        rearForward = chosen.rearForward or forward,
        rearHeight = chosen.rearHeight or height,
        rearPitch = chosen.rearPitch or pitch,
    }
end

local function getDashcamModels()
    return (Config.Dashcam and Config.Dashcam.Positions and Config.Dashcam.Positions.models) or {}
end

-- By config model name (used for the far-away feed path where we have no entity)
local function getDashcamOffsetByName(name)
    return buildDashcamOffset(name and getDashcamModels()[name] or nil)
end

-- By vehicle model hash (used when the vehicle is streamed locally)
local function getDashcamOffset(veh)
    local hash = GetEntityModel(veh)
    for name, off in pairs(getDashcamModels()) do
        if GetHashKey(name) == hash then
            return buildDashcamOffset(off)
        end
    end
    return nil
end

updateCameraControls = function()
    if not isViewingCamera or not currentCamera then
        return
    end

    -- For bodycams, attach camera to the target ped's head bone so it follows movement
    if currentCameraData and currentCameraData.isBodycam and currentCameraData.targetSource then
        local targetPed = GetPlayerPed(GetPlayerFromServerId(currentCameraData.targetSource))
        if targetPed and targetPed ~= 0 and DoesEntityExist(targetPed) then
            local forward = GetEntityForwardVector(targetPed)
            local pedCoords = GetEntityCoords(targetPed)

            local camX = pedCoords.x + forward.x * 0.3
            local camY = pedCoords.y + forward.y * 0.3
            local camZ = pedCoords.z + 0.4

            SetCamCoord(currentCamera, camX, camY, camZ)

            local heading = GetEntityHeading(targetPed)
            local camZ_rot = heading

            SetCamRot(currentCamera, -10.0, 0.0, camZ_rot, 2)
            SetFocusPosAndVel(camX, camY, camZ, 0, 0, 0)
        end
    end

    -- For dashcams, attach the camera to the target's vehicle (front or rear).
    -- If the vehicle is streamed locally we attach to the entity (smooth, exact).
    -- Otherwise we fall back to the server-pushed live transform: force-stream
    -- that area and position the camera from the fed coords/heading so far-away
    -- units are still viewable.
    if currentCameraData and currentCameraData.isDashcam then
        local veh = nil
        if currentCameraData.vehicleNetId and NetworkDoesNetworkIdExist(currentCameraData.vehicleNetId) then
            local e = NetworkGetEntityFromNetworkId(currentCameraData.vehicleNetId)
            if e and e ~= 0 and DoesEntityExist(e) then veh = e end
        end
        if not veh and currentCameraData.targetSource then
            local tped = GetPlayerPed(GetPlayerFromServerId(currentCameraData.targetSource))
            if tped and tped ~= 0 then
                local v = GetVehiclePedIsIn(tped, false)
                if v and v ~= 0 then veh = v end
            end
        end

        if veh and veh ~= 0 and DoesEntityExist(veh) then
            -- Streamed locally: attach directly to the entity (best quality)
            dashcamRenderCoords = nil
            local off = getDashcamOffset(veh)
            if off then
            local pos
            local heading = GetEntityHeading(veh)
            local yaw

            if dashcamRear then
                pos = GetOffsetFromEntityInWorldCoords(veh, off.rearSide, -off.rearForward, off.rearHeight)
                yaw = (heading + 180.0) % 360.0
                SetCamRot(currentCamera, off.rearPitch, 0.0, yaw, 2)
            else
                pos = GetOffsetFromEntityInWorldCoords(veh, off.side, off.forward, off.height)
                yaw = heading
                SetCamRot(currentCamera, off.pitch, 0.0, yaw, 2)
            end

            SetCamCoord(currentCamera, pos.x, pos.y, pos.z)
            SetFocusPosAndVel(pos.x, pos.y, pos.z, 0, 0, 0)
            dashcamSpeedKmh = GetEntitySpeed(veh) * 3.6
            end

        elseif dashcamFeed then
            -- Not streamed: use the server-pushed transform. Force-stream the
            -- area so the world/vehicle around it loads in (then the branch above
            -- takes over once the entity exists).
            local fc = dashcamFeed.coords
            SetFocusPosAndVel(fc.x, fc.y, fc.z, 0.0, 0.0, 0.0)

            -- Offset by the configured model (server tells us which one)
            local off = getDashcamOffsetByName(currentCameraData.dashcamModel)
            if off then
            local h = math.rad(dashcamFeed.heading or 0.0)
            local fwd = vector3(-math.sin(h), math.cos(h), 0.0)
            local right = vector3(math.cos(h), math.sin(h), 0.0)

            local side, fdist, height, pitch, yaw
            if dashcamRear then
                side, fdist, height, pitch = off.rearSide, -off.rearForward, off.rearHeight, off.rearPitch
                yaw = (dashcamFeed.heading + 180.0) % 360.0
            else
                side, fdist, height, pitch = off.side, off.forward, off.height, off.pitch
                yaw = dashcamFeed.heading
            end

            local target = vector3(
                fc.x + right.x * side + fwd.x * fdist,
                fc.y + right.y * side + fwd.y * fdist,
                fc.z + height
            )

            -- Smooth the 250ms server steps by easing toward the target
            if not dashcamRenderCoords then
                dashcamRenderCoords = target
            else
                local a = 0.2
                dashcamRenderCoords = vector3(
                    dashcamRenderCoords.x + (target.x - dashcamRenderCoords.x) * a,
                    dashcamRenderCoords.y + (target.y - dashcamRenderCoords.y) * a,
                    dashcamRenderCoords.z + (target.z - dashcamRenderCoords.z) * a
                )
            end

            SetCamCoord(currentCamera, dashcamRenderCoords.x, dashcamRenderCoords.y, dashcamRenderCoords.z)
            SetCamRot(currentCamera, pitch, 0.0, yaw, 2)
            dashcamSpeedKmh = (dashcamFeed.speed or 0.0) * 3.6
            end
        end
    end

    -- Handle zoom controls (adjust FOV instead of position for CCTV)
    local currentFov = GetCamFov(currentCamera)
    local fovStep = camCfg.FovStep or 2.0
    if IsDisabledControlPressed(2, 241) then -- Mouse wheel up (zoom in)
        currentFov = currentFov - fovStep
    end

    if IsDisabledControlPressed(2, 242) then -- Mouse wheel down (zoom out)
        currentFov = currentFov + fovStep
    end

    -- Clamp FOV values (lower FOV = more zoomed in)
    currentFov = math.max(camCfg.FovMin or 10.0, math.min(camCfg.FovMax or 100.0, currentFov))
    SetCamFov(currentCamera, currentFov)

    -- Handle mouse look controls for CCTV rotation (static cameras only)
    if not (currentCameraData and (currentCameraData.isBodycam or currentCameraData.isDashcam)) then
        local mouseX = GetDisabledControlNormal(0, 1) * cameraOptions.rotationSpeed
        local mouseY = GetDisabledControlNormal(0, 2) * cameraOptions.rotationSpeed

        -- Get current rotation and apply mouse input
        local currentRot = GetCamRot(currentCamera, 2)
        local newRotX = currentRot.x - mouseY * 30.0  -- Vertical look
        local newRotZ = currentRot.z - mouseX * 30.0  -- Horizontal look

        -- Limit vertical rotation
        newRotX = math.max(-45.0, math.min(45.0, newRotX))

        -- Apply new rotation while keeping camera at current position
        local currentCoords = GetCamCoord(currentCamera)
        SetCamCoord(currentCamera, currentCoords.x, currentCoords.y, currentCoords.z)
        SetCamRot(currentCamera, newRotX, currentRot.y, newRotZ, 2)
    end

    -- The on-screen overlay (drawn each frame in the control thread) shows the
    -- camera name, REC/LIVE state, timestamp, zoom and controls.
end

-- Camera control thread - spawned on demand, exits when camera view stops
local cameraControlThreadActive = false

startCameraControlThread = function()
    if cameraControlThreadActive then return end
    cameraControlThreadActive = true

    CreateThread(function()
        -- Sync real server time once for the overlay clock
        syncServerTime()
        dashcamRear = false
        dashcamSpeedKmh = 0
        dashcamFeed = nil
        dashcamRenderCoords = nil

        while isViewingCamera do
            -- Update camera controls
            updateCameraControls()

            -- Dashcam: toggle front/rear camera with [E]
            if currentCameraData and currentCameraData.isDashcam then
                DisableControlAction(0, 51, true) -- INPUT_CONTEXT (E)
                if IsDisabledControlJustPressed(0, 51) then
                    dashcamRear = not dashcamRear
                end
            end

            -- Draw the CCTV overlay (name, REC/LIVE, timestamp, zoom, controls)
            drawCameraOverlay()

            -- Check for ESC key to exit camera view
            if IsControlJustPressed(0, 177) or IsControlJustPressed(0, 200) then
                stopCameraView(true)
                break
            end

            -- Disable player controls while viewing camera
            DisablePlayerFiring(PlayerPedId(), true)
            DisableControlAction(0, 1, true) -- LookLeftRight
            DisableControlAction(0, 2, true) -- LookUpDown
            DisableControlAction(0, 24, true) -- Attack
            DisableControlAction(0, 257, true) -- Attack2
            DisableControlAction(0, 25, true) -- Aim
            DisableControlAction(0, 263, true) -- Melee Attack 1
            DisableControlAction(0, 32, true) -- MoveUpOnly
            DisableControlAction(0, 33, true) -- MoveDownOnly
            DisableControlAction(0, 34, true) -- MoveLeftOnly
            DisableControlAction(0, 35, true) -- MoveRightOnly
            DisableControlAction(0, 30, true) -- MoveLeftRight
            DisableControlAction(0, 31, true) -- MoveUpDown
            DisableControlAction(0, 36, true) -- Duck
            DisableControlAction(0, 21, true) -- Sprint
            DisableControlAction(0, 22, true) -- Jump
            DisableControlAction(0, 23, true) -- Enter
            DisableControlAction(0, 75, true) -- Exit Vehicle
            DisableControlAction(27, 75, true) -- Exit Vehicle
            DisableControlAction(0, 26, true) -- Look Behind
            DisableControlAction(0, 73, true) -- Disable clearing wanted level
            DisableControlAction(2, 199, true) -- Disable pause menu
            DisableControlAction(2, 200, true) -- Disable pause menu

            Wait(0)
        end
        cameraControlThreadActive = false
    end)
end

-- Camera Feed Placer ----------------------------------
-- A free-fly camera that lets an admin aim what a static camera actually shows
-- (the "feed"), decoupled from where the physical prop sits. Returns
-- { coords = vector3, rotation = vector3, fov = number } on confirm, or nil if
-- cancelled.
--
-- Controls: WASD move, SPACE/CTRL up/down, SHIFT faster, mouse look,
--           scroll = zoom (FOV), ENTER confirm, BACKSPACE cancel.
local function setupCameraFeed(startCoords, startRot, startFov)
    local cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    if not cam or cam == 0 then
        ps.error('setupCameraFeed - failed to create camera')
        return nil
    end

    local coords = vector3(startCoords.x, startCoords.y, startCoords.z)
    local pitch = startRot and startRot.x or 0.0
    local yaw = startRot and startRot.z or 0.0
    local fov = startFov or 50.0

    SetCamCoord(cam, coords.x, coords.y, coords.z)
    SetCamRot(cam, pitch, 0.0, yaw, 2)
    SetCamFov(cam, fov)
    SetCamActive(cam, true)
    RenderScriptCams(true, false, 0, true, true)
    SetTimecycleModifier('scanline_cam_cheap')
    SetTimecycleModifierStrength(1.0)

    local result = nil
    local lookSens = 8.0
    local baseSpeed = 0.10

    while true do
        Wait(0)

        local ped = PlayerPedId()

        -- Disable everything that would move the ped / camera / open menus
        DisablePlayerFiring(ped, true)
        DisableControlAction(0, 1, true)   -- look LR
        DisableControlAction(0, 2, true)   -- look UD
        DisableControlAction(0, 24, true)  -- attack
        DisableControlAction(0, 25, true)  -- aim
        DisableControlAction(0, 30, true)  -- move LR
        DisableControlAction(0, 31, true)  -- move UD
        DisableControlAction(0, 32, true)  -- W
        DisableControlAction(0, 33, true)  -- S
        DisableControlAction(0, 34, true)  -- A
        DisableControlAction(0, 35, true)  -- D
        DisableControlAction(0, 21, true)  -- sprint
        DisableControlAction(0, 22, true)  -- jump (used for up)
        DisableControlAction(0, 36, true)  -- duck (used for down)
        DisableControlAction(0, 44, true)  -- cover
        DisableControlAction(0, 23, true)  -- enter
        DisableControlAction(0, 75, true)  -- exit vehicle
        DisableControlAction(0, 199, true) -- pause
        DisableControlAction(0, 200, true) -- pause alt

        -- Mouse look
        yaw = (yaw - GetDisabledControlNormal(0, 1) * lookSens) % 360.0
        pitch = math.max(-89.0, math.min(89.0, pitch - GetDisabledControlNormal(0, 2) * lookSens))

        -- Direction vectors from current yaw/pitch
        local radYaw = math.rad(yaw)
        local radPitch = math.rad(pitch)
        local cosPitch = math.cos(radPitch)
        local forward = vector3(-math.sin(radYaw) * cosPitch, math.cos(radYaw) * cosPitch, math.sin(radPitch))
        local right = vector3(math.cos(radYaw), math.sin(radYaw), 0.0)

        local speed = baseSpeed
        if IsDisabledControlPressed(0, 21) then speed = baseSpeed * 5.0 end -- shift = faster

        if IsDisabledControlPressed(0, 32) then coords = coords + forward * speed end -- W
        if IsDisabledControlPressed(0, 33) then coords = coords - forward * speed end -- S
        if IsDisabledControlPressed(0, 35) then coords = coords + right * speed end   -- D
        if IsDisabledControlPressed(0, 34) then coords = coords - right * speed end   -- A
        if IsDisabledControlPressed(0, 22) then coords = vector3(coords.x, coords.y, coords.z + speed) end -- space up
        if IsDisabledControlPressed(0, 36) then coords = vector3(coords.x, coords.y, coords.z - speed) end -- ctrl down

        -- Zoom (FOV)
        if IsDisabledControlPressed(0, 241) then fov = math.max(10.0, fov - 1.0) end -- wheel up
        if IsDisabledControlPressed(0, 242) then fov = math.min(100.0, fov + 1.0) end -- wheel down

        SetCamCoord(cam, coords.x, coords.y, coords.z)
        SetCamRot(cam, pitch, 0.0, yaw, 2)
        SetCamFov(cam, fov)
        SetFocusPosAndVel(coords.x, coords.y, coords.z, 0.0, 0.0, 0.0)

        ShowCameraHelpNotification(
            'Set Camera Feed' ..
            '~n~WASD: Move  |  Space/Ctrl: Up/Down  |  Shift: Faster' ..
            '~n~Mouse: Aim  |  Scroll: Zoom (FOV ' .. string.format('%.0f', fov) .. ')' ..
            '~n~~INPUT_FRONTEND_ACCEPT~ Confirm  |  ~INPUT_FRONTEND_CANCEL~ Cancel'
        )

        if IsControlJustPressed(0, 201) or IsControlJustPressed(0, 18) then -- Enter
            result = {
                coords = vector3(coords.x, coords.y, coords.z),
                rotation = vector3(pitch, 0.0, yaw),
                fov = fov
            }
            break
        end

        if IsControlJustPressed(0, 202) or IsControlJustPressed(0, 177) then -- Backspace / Esc
            result = nil
            break
        end
    end

    RenderScriptCams(false, false, 0, true, true)
    SetCamActive(cam, false)
    DestroyCam(cam, false)
    ClearTimecycleModifier()
    ClearFocus()

    return result
end

-- Camera Placement ------------------------------------

-- Help func to validate and extract vector4 components
local function parseVector4(str)
    if not str or type(str) ~= 'string' then
        return nil
    end

    -- Remove all whitespace first
    str = str:gsub('%s+', '')

    -- Extract numbers from vector4(x, y, z, w) format
    local x, y, z, w = str:match("vector4%(([%d%.%-]+),([%d%.%-]+),([%d%.%-]+),([%d%.%-]+)%)")
    if x and y and z and w then
        return tonumber(x), tonumber(y), tonumber(z), tonumber(w)
    end

    return nil
end

-- Format current position as vector4
local function getCurrentPositionVector4()
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)

    return string.format('vector4(%.2f, %.2f, %.2f, %.0f)',
        coords.x,
        coords.y,
        coords.z,
        heading)
end

-- Get all available camera models from server
local function getCameraModels()
    -- Use cached version if available
    if cameraModelsCache then
        return cameraModelsCache
    end

    -- Fetch models from server
    local models = ps.callback('ps-mdt:server:getCameraModels')
    if models then
        cameraModelsCache = models -- Cache the result
        return models
    else
        -- Fallback in case callback fails
        ps.error('Failed to fetch camera models from server')
        return {
            { value = 'security_cam_03', label = 'Security Cam 03 (Default)' }
        }
    end
end

-- Function to clear camera models cache (useful if models are updated on server)
local function clearCameraModelsCache()
    cameraModelsCache = nil
    ps.debug('Camera models cache cleared')
end

-- Helper func to get the actual model name from the selected key
local function getModelNameFromKey(selectedKey)
    local models = getCameraModels()
    for _, model in ipairs(models) do
        if model.value == selectedKey then
            return model.model
        end
    end
    -- Fallback to a default model if not found
    ps.warn('Model key not found: ' .. tostring(selectedKey) .. ', using fallback')
    return 'prop_cctv_cam_06a'
end

-- Show camera placement menu
function CameraPlacement.showPlacementMenu()
    local input = lib.inputDialog('Camera Placement System', {
        {
            type = 'input',
            label = 'Camera ID',
            description = 'Unique identifier for this camera',
            required = true,
            placeholder = 'cam_001'
        },
        {
            type = 'input',
            label = 'Camera Label',
            description = 'Display name for this camera',
            required = true,
            placeholder = 'Police Station Entrance'
        },
        {
            type = 'select',
            label = 'Camera Model',
            description = 'Select the camera model to spawn',
            required = true,
            options = getCameraModels(),
            default = 'security_cam_03'
        },
        {
            type = 'input',
            label = 'Position (Vector4)',
            description = 'Camera position and rotation as vector4(x, y, z, heading)',
            required = true,
            default = getCurrentPositionVector4(),
            placeholder = 'vector4(0, 0, 0, 0)'
        },
    })

    if not input then
        ps.info('Camera placement cancelled')
        ps.notify('Camera placement cancelled', 'info')
        return
    end

    -- Validate camera ID format
    if not tostring(input[1]):match("^[a-zA-Z0-9_%-]+$") then
        ps.warn('Invalid camera ID format', 'error')
        ps.notify('Camera ID can only contain letters, numbers, underscores, and dashes', 'error')
        return
    end

    -- Parse vector4 position input
    local positionStr = tostring(input[4])
    local x, y, z, heading = parseVector4(positionStr)

    if not x or not y or not z or not heading then
        ps.warn('Invalid vector4 format', 'error')
        ps.notify('Invalid vector4 format. Use: vector4(x, y, z, heading)', 'error')
        return
    end

    -- Validate coordinate ranges
    if x < -4000 or x > 4000 or y < -4000 or y > 4000 or z < -100 or z > 1000 then
        ps.warn('Coordinates out of range', 'error')
        ps.notify('Coordinates out of range. X,Y: -4000 to 4000, Z: -100 to 1000', 'error')
        return
    end

    -- Normalize heading to 0-360 range
    heading = heading % 360
    if heading < 0 then heading = heading + 360 end

    -- Validate camera model with server
    local modelValid = ps.callback('ps-mdt:server:validateCameraModel', tostring(input[3]))
    if not modelValid then
        ps.warn('Invalid camera model selected: ' .. tostring(input[3]))
        ps.notify('Invalid camera model selected', 'error')
        return
    end

    -- Prepare camera data
    local cameraData = {
        camId = tostring(input[1]),
        camLabel = tostring(input[2]),
        model = tostring(input[3]),
        coords = vector3(x, y, z),
        rotation = vector3(0.0, 0.0, heading),
    }

    -- Send to server for creation
    TriggerServerEvent(resourceName .. ':server:createStaticCamera', cameraData)
    ps.info('Camera placement request sent to server for:' .. cameraData.camId)
end

-- Get existing cams
function CameraPlacement.showManagementMenu()
    TriggerServerEvent(resourceName .. ':server:requestCameraList')
end

-- Handle camera list response from server
RegisterNetEvent(resourceName .. ':client:receiveCameraList', function(cameras)
    if not cameras or #cameras == 0 then
        ps.info('No cameras found')
        ps.notify('No cameras found', 'info')
        return
    end

    local options = {}

    for _, camera in ipairs(cameras) do
        table.insert(options, {
            title = camera.camLabel,
            description = string.format('ID: %s | Model: %s | Spawned: %s | Viewers: %d', 
                camera.camId, camera.model, camera.isSpawned and 'Yes' or 'No', camera.viewerCount),
            metadata = {
                'Camera ID: ' .. camera.camId,
                'Coordinates: ' .. string.format('%.2f, %.2f, %.2f', camera.coords.x, camera.coords.y, camera.coords.z),
            },
            onSelect = function()
                CameraPlacement.showCameraActions(camera)
            end
        })
    end

    lib.registerContext({
        id = 'camera_management',
        title = 'Camera Management',
        options = options
    })

    lib.showContext('camera_management')
end)

-- Show individual camera action menu
function CameraPlacement.showCameraActions(camera)
    local options = {
        {
            title = 'View Camera Feed',
            description = 'Start viewing through this camera',
            icon = 'video',
            onSelect = function()
                TriggerServerEvent(resourceName .. ':server:activateCamera', camera.camId)
            end
        },
        {
            title = 'Edit Camera',
            description = 'Modify camera position and settings',
            icon = 'pencil',
            onSelect = function()
                CameraPlacement.showEditMenu(camera)
            end
        },
        {
            title = 'Reposition Prop with Gizmo',
            description = 'Move the physical camera model using the 3D gizmo',
            icon = 'cube',
            onSelect = function()
                CameraPlacement.placeWithGizmo(camera)
            end
        },
        {
            title = 'Edit Camera Feed',
            description = 'Re-aim what this camera shows (free-fly view)',
            icon = 'video',
            onSelect = function()
                CameraPlacement.editFeed(camera)
            end
        }
    }

    if camera.isSpawned then
        table.insert(options, {
            title = 'Despawn Camera',
            description = 'Remove camera from world',
            icon = 'eye-slash',
            onSelect = function()
                TriggerServerEvent(resourceName .. ':server:despawnCamera', camera.camId)
            end
        })
    else
        table.insert(options, {
            title = 'Spawn Camera',
            description = 'Place camera in world',
            icon = 'eye',
            onSelect = function()
                TriggerServerEvent(resourceName .. ':server:spawnCamera', camera.camId)
            end
        })
    end

    table.insert(options, {
        title = 'Delete Camera',
        description = 'Permanently delete this camera',
        icon = 'trash',
        onSelect = function()
            local alert = lib.alertDialog({
                header = 'Delete Camera',
                content = 'Are you sure you want to delete camera "' .. camera.camLabel .. '"?\n\nThis action cannot be undone.',
                centered = true,
                cancel = true
            })

            if alert == 'confirm' then
                TriggerServerEvent(resourceName .. ':server:deleteCamera', camera.camId)
            end
        end
    })

    lib.registerContext({
        id = 'camera_actions',
        title = camera.camLabel .. ' - Actions',
        menu = 'camera_management',
        options = options
    })

    lib.showContext('camera_actions')
end

-- Show camera edit menu
function CameraPlacement.showEditMenu(camera)
    local currentPosition = string.format('vector4(%.2f, %.2f, %.2f, %.0f)',
        camera.coords.x, camera.coords.y, camera.coords.z, camera.rotation.z)

    local input = lib.inputDialog('Edit Camera: ' .. camera.camLabel, {
        {
            type = 'input',
            label = 'Camera Label',
            description = 'Display name for this camera',
            required = true,
            default = camera.camLabel,
            placeholder = 'Police Station Entrance'
        },
        {
            type = 'select',
            label = 'Camera Model',
            description = 'Select the camera model to spawn',
            required = true,
            options = getCameraModels(),
            default = camera.model
        },
        {
            type = 'input',
            label = 'Position (Vector4)',
            description = 'Camera position and rotation as vector4(x, y, z, heading)',
            required = true,
            default = currentPosition,
            placeholder = 'vector4(0, 0, 0, 0)'
        }
    })

    if not input then
        ps.info('Camera edit cancelled')
        ps.notify('Camera edit cancelled', 'info')
        return
    end

    -- Parse vector4 position input
    local positionStr = tostring(input[3])
    local x, y, z, heading = parseVector4(positionStr)

    if not x or not y or not z or not heading then
        ps.warn('Invalid vector4 format', 'error')
        ps.notify('Invalid vector4 format. Use: vector4(x, y, z, heading)', 'error')
        return
    end

    -- Validate coordinate ranges
    if x < -4000 or x > 4000 or y < -4000 or y > 4000 or z < -100 or z > 1000 then
        ps.warn('Coordinates out of range', 'error')
        ps.notify('Coordinates out of range. X,Y: -4000 to 4000, Z: -100 to 1000', 'error')
        return
    end

    -- Normalize heading to 0-360 range
    heading = heading % 360
    if heading < 0 then heading = heading + 360 end

    -- Validate camera model with server
    local modelValid = ps.callback('ps-mdt:server:validateCameraModel', tostring(input[2]))
    if not modelValid then
        ps.warn('Invalid camera model selected: ' .. tostring(input[2]))
        ps.notify('Invalid camera model selected', 'error')
        return
    end

    -- Prepare updated camera data
    local updateData = {
        camId = camera.camId,
        camLabel = tostring(input[1]),
        model = tostring(input[2]),
        coords = vector3(x, y, z),
        rotation = vector3(0.0, 0.0, heading)
    }

    -- Send to server for update
    local result = ps.callback(resourceName .. ':server:updateCamera', updateData)
    if result and result.success then
        ps.info('Camera update request sent to server for: ' .. camera.camId)
    else
        ps.warn('Camera update failed for: ' .. camera.camId)
        ps.notify('Camera update failed', 'error')
    end
end

-- Create camera with gizmo placement
function CameraPlacement.createWithGizmo()
    local input = lib.inputDialog('Create Camera with Gizmo', {
        {
            type = 'input',
            label = 'Camera ID',
            description = 'Unique identifier for this camera',
            required = true,
            placeholder = 'cam_001'
        },
        {
            type = 'input',
            label = 'Camera Label',
            description = 'Display name for this camera',
            required = true,
            placeholder = 'Police Station Entrance'
        },
        {
            type = 'select',
            label = 'Camera Model',
            description = 'Select the camera model to spawn',
            required = true,
            options = getCameraModels(),
            default = 'security_cam_03'
        }
    })

    if not input then
        ps.info('Camera creation cancelled')
        ps.notify('Camera creation cancelled', 'info')
        return
    end

    -- Validate camera ID format
    if not tostring(input[1]):match("^[a-zA-Z0-9_%-]+$") then
        ps.warn('Invalid camera ID format', 'error')
        ps.notify('Camera ID can only contain letters, numbers, underscores, and dashes', 'error')
        return
    end

    -- Validate camera model with server
    local modelValid = ps.callback('ps-mdt:server:validateCameraModel', tostring(input[3]))
    if not modelValid then
        ps.warn('Invalid camera model selected: ' .. tostring(input[3]))
        ps.notify('Invalid camera model selected', 'error')
        return
    end

    -- Create a temporary prop to position with gizmo
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local forwardVector = GetEntityForwardVector(ped)
    local spawnCoords = coords + forwardVector * 3.0

    -- Request the selected camera model hash
    local selectedKey = tostring(input[3])
    local actualModelName = getModelNameFromKey(selectedKey)
    local modelHash = GetHashKey(actualModelName)

    ps.debug('Selected key: ' .. selectedKey .. ', Model name: ' .. actualModelName .. ', Hash: ' .. tostring(modelHash))
    lib.requestModel(modelHash)

    -- Create temporary object
    local tempObj = CreateObject(modelHash, spawnCoords.x, spawnCoords.y, spawnCoords.z + 1.0, false, false, false)

    if not tempObj or tempObj == 0 then
        ps.error('Failed to create temporary camera object for placement')
        ps.notify('Failed to create placement object', 'error')
        return
    end
    ps.debug('Created temporary object for gizmo placement')

    -- Use gizmo for placement
    ps.notify('Use the gizmo to position the camera, then press ENTER when done', 'info')
    local gizmoResult = exports[GetCurrentResourceName()]:useGizmo(tempObj)

    if not gizmoResult then
        ps.warn('Gizmo placement cancelled')
        ps.notify('Camera placement cancelled', 'info')
        DeleteObject(tempObj)
        return
    end

    -- Get final prop position and rotation (the physical model only)
    local finalCoords = gizmoResult.position
    local finalRotation = gizmoResult.rotation

    ps.debug('Gizmo final position: ' .. tostring(finalCoords))
    ps.debug('Final rotation: ' .. tostring(finalRotation))

    -- Step 2: aim the camera feed. The temp prop stays visible so the operator
    -- can see the camera while framing the shot. Start at the prop, looking the
    -- way the lens points (heading + 180).
    ps.notify('Now aim the camera feed - move/look, then ENTER to confirm', 'info')
    local feed = setupCameraFeed(
        vector3(finalCoords.x, finalCoords.y, finalCoords.z),
        vector3(0.0, 0.0, (finalRotation.z + 180.0) % 360.0),
        50.0
    )

    -- Clean up temporary object now that both steps are done
    DeleteObject(tempObj)
    SetModelAsNoLongerNeeded(modelHash)

    if not feed then
        ps.warn('Camera feed setup cancelled')
        ps.notify('Camera creation cancelled', 'info')
        return
    end

    -- Prepare camera data (prop transform + decoupled feed transform)
    local cameraData = {
        camId = tostring(input[1]),
        camLabel = tostring(input[2]),
        model = tostring(input[3]),
        coords = vector3(finalCoords.x, finalCoords.y, finalCoords.z),
        rotation = vector3(finalRotation.x, finalRotation.y, finalRotation.z),
        feedCoords = feed.coords,
        feedRotation = feed.rotation,
        feedFov = feed.fov,
    }

    ps.debug('Camera data being sent to server:')
    ps.debug('  coords: ' .. tostring(cameraData.coords))
    ps.debug('  rotation: ' .. tostring(cameraData.rotation))
    ps.debug('  feedCoords: ' .. tostring(cameraData.feedCoords))

    -- Send to server for creation
    TriggerServerEvent(resourceName .. ':server:createStaticCamera', cameraData)
    ps.info('Camera placement request sent to server for: ' .. cameraData.camId)
    ps.notify('Camera created: ' .. cameraData.camLabel, 'success')
end

-- Position existing camera with gizmo
function CameraPlacement.placeWithGizmo(camera)
    -- Get the actual model name for the existing camera
    local actualModelName = getModelNameFromKey(camera.model)
    local modelHash = GetHashKey(actualModelName)

    ps.debug('Repositioning camera with key: ' .. camera.model .. ', Model name: ' .. actualModelName .. ', Hash: ' .. tostring(modelHash))
    lib.requestModel(modelHash)

    -- Create temporary object at current camera position
    local tempObj = CreateObject(modelHash, camera.coords.x, camera.coords.y, camera.coords.z, false, false, false)

    if not tempObj or tempObj == 0 then
        ps.error('Failed to create temporary camera object for placement')
        ps.notify('Failed to create placement object', 'error')
        return
    end

    SetEntityRotation(tempObj, camera.rotation.x, camera.rotation.y, camera.rotation.z, 2, false)

    ps.debug('Created temporary object for gizmo repositioning')

    ps.notify('Use the gizmo to reposition camera "' .. camera.camLabel .. '", then press ENTER when done', 'info')

    local gizmoResult = exports[GetCurrentResourceName()]:useGizmo(tempObj)

    if not gizmoResult then
        ps.warn('Gizmo placement cancelled')
        ps.notify('Camera repositioning cancelled', 'info')
        DeleteObject(tempObj)
        return
    end

    -- Get final position and rotation directly from gizmo
    -- The gizmo result already represents where the user wants the entity to be
    local finalCoords = gizmoResult.position
    local finalRotation = gizmoResult.rotation

    ps.debug('Gizmo final position: ' .. tostring(finalCoords))
    ps.debug('Final rotation: ' .. tostring(finalRotation))

    -- Clean up temporary object
    DeleteObject(tempObj)
    SetModelAsNoLongerNeeded(modelHash)

    -- Prepare update data
    local updateData = {
        camId = camera.camId,
        coords = vector3(finalCoords.x, finalCoords.y, finalCoords.z),
        rotation = vector3(finalRotation.x, finalRotation.y, finalRotation.z)
    }

    -- Send to server for update
    local result = ps.callback(resourceName .. ':server:updateCamera', updateData)
    if not result or not result.success then
        ps.warn('Camera update failed for: ' .. camera.camId)
        ps.notify('Camera update failed', 'error')
    end
    ps.info('Camera repositioning request sent to server for: ' .. camera.camId)
    ps.notify('Camera repositioned at: ' .. string.format('%.2f, %.2f, %.2f', finalCoords.x, finalCoords.y, finalCoords.z), 'success')
end

-- Re-aim the camera feed (decoupled from the prop) using the free-fly placer
function CameraPlacement.editFeed(camera)
    -- Start from the existing feed if set, otherwise from the prop looking the
    -- way the lens points (heading + 180).
    local startCoords, startRot, startFov
    if camera.feedCoords and camera.feedRotation then
        startCoords = vector3(camera.feedCoords.x, camera.feedCoords.y, camera.feedCoords.z)
        startRot = vector3(camera.feedRotation.x, camera.feedRotation.y, camera.feedRotation.z)
        startFov = camera.feedFov or 50.0
    else
        startCoords = vector3(camera.coords.x, camera.coords.y, camera.coords.z)
        startRot = vector3(0.0, 0.0, (camera.rotation.z + 180.0) % 360.0)
        startFov = 50.0
    end

    ps.notify('Aim the camera feed for "' .. camera.camLabel .. '", then ENTER to confirm', 'info')
    local feed = setupCameraFeed(startCoords, startRot, startFov)

    if not feed then
        ps.notify('Camera feed edit cancelled', 'info')
        return
    end

    local updateData = {
        camId = camera.camId,
        feedCoords = feed.coords,
        feedRotation = feed.rotation,
        feedFov = feed.fov,
    }

    local result = ps.callback(resourceName .. ':server:updateCamera', updateData)
    if result and result.success then
        ps.info('Camera feed updated for: ' .. camera.camId)
        ps.notify('Camera feed updated', 'success')
    else
        ps.warn('Camera feed update failed for: ' .. camera.camId)
        ps.notify('Camera feed update failed', 'error')
    end
end

-- Main camera menu
function CameraPlacement.showMainMenu()
    lib.registerContext({
        id = 'camera_main_menu',
        title = 'Camera System',
        options = {
            {
                title = 'Place New Camera',
                description = 'Create a new camera',
                icon = 'plus',
                onSelect = function()
                    CameraPlacement.showPlacementMenu()
                end
            },
            {
                title = 'Create with Gizmo',
                description = 'Create a new camera using Gizmo',
                icon = 'cube',
                onSelect = function()
                    CameraPlacement.createWithGizmo()
                end
            },
            {
                title = 'Manage Cameras',
                description = 'View and manage existing cameras',
                icon = 'cog',
                onSelect = function()
                    CameraPlacement.showManagementMenu()
                end
            },
        }
    })

    lib.showContext('camera_main_menu')
end

-- Camera Placer entry point -------------------------------
-- Opened from the server's lib.addCommand handler, which already enforces the
-- admin (restricted) check, so this just shows the menu.
RegisterNetEvent(resourceName .. ':client:openCameraPlacer', function()
    CameraPlacement.showMainMenu()
end)

-- Live dashcam transform from the server (enables viewing far-away units)
RegisterNetEvent(resourceName .. ':client:dashcamTransform', function(data)
    if not isViewingCamera or not currentCameraData or not currentCameraData.isDashcam then return end
    if not data or not data.coords then return end
    if currentCameraData.dashcamId and data.dashcamId and data.dashcamId ~= currentCameraData.dashcamId then return end

    dashcamFeed = {
        coords = vector3(data.coords.x, data.coords.y, data.coords.z),
        heading = data.heading or 0.0,
        speed = data.speed or 0.0,
        vehicleNetId = data.vehicleNetId,
        t = GetGameTimer(),
    }
    -- Keep the net id fresh in case the vehicle re-streamed with a new handle
    if data.vehicleNetId then currentCameraData.vehicleNetId = data.vehicleNetId end
end)

-- Dashcam ended server-side (officer left the vehicle / went off duty)
RegisterNetEvent(resourceName .. ':client:dashcamEnded', function(dashcamId)
    if not isViewingCamera or not currentCameraData or not currentCameraData.isDashcam then return end
    if dashcamId and currentCameraData.dashcamId and dashcamId ~= currentCameraData.dashcamId then return end
    ps.notify('Dashcam ended - unit is no longer driving', 'info')
    stopCameraView(false)
end)

-- Report to the server when this player is the driver of an emergency-class
-- vehicle (police car), so the server knows which units actually have a dashcam.
-- GetVehicleClass isn't reliable server-side, so the check runs here (same
-- approach as the tracking system). Sends only on change to minimise traffic.
CreateThread(function()
    local emergencyClass = (Config.Dashcam and Config.Dashcam.EmergencyClass) or 18
    local lastKey = nil
    while true do
        Wait(2000)
        local ped = PlayerPedId()
        local isCopDriver, plate = false, nil
        if ped and ped ~= 0 and IsPedInAnyVehicle(ped, false) then
            local veh = GetVehiclePedIsIn(ped, false)
            if veh ~= 0 and GetPedInVehicleSeat(veh, -1) == ped and GetVehicleClass(veh) == emergencyClass then
                isCopDriver = true
                plate = (GetVehicleNumberPlateText(veh) or ''):gsub('%s+', '')
            end
        end
        local key = isCopDriver and plate or false
        if key ~= lastKey then
            lastKey = key
            TriggerServerEvent(resourceName .. ':server:dashcamVehicleState', isCopDriver and { plate = plate } or nil)
        end
    end
end)

-- Exports --------------------------------------

-- Check if currently viewing a camera
exports('isViewingCamera', function()
    return isViewingCamera
end)

-- Cleanup on resource stop
AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    if isViewingCamera and currentCamera then
        SetCamActive(currentCamera, false)
        RenderScriptCams(false, false, 0, true, true)
        DestroyCam(currentCamera, false)
        currentCamera = nil
        isViewingCamera = false
    end
    if hiddenCameraEntity and DoesEntityExist(hiddenCameraEntity) then
        SetEntityVisible(hiddenCameraEntity, true, false)
        hiddenCameraEntity = nil
    end
    ClearTimecycleModifier()
    ClearFocus()
    DoScreenFadeIn(0)
end)