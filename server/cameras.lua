-- Core camera system
-- Bodycam integration is handled in server/backend/bodycams.lua
-- Camera health/destruction hooks are tracked on the client

local resourceName = tostring(GetCurrentResourceName())

local spawnedCameras = {} -- Track spawned cameras
local playerViewingCamera = {} -- Track players viewing cameras

Camera = {}
Camera.__index = Camera

-- Available camera models for static cameras
Camera.models = (Config and Config.CameraModels) or {
    ['security_cam_01'] = 'v_serv_securitycam_1a',
    ['security_cam_02'] = 'v_serv_securitycam_03',
    ['security_cam_03'] = 'ba_prop_battle_cctv_cam_01a',
    ['security_cam_04'] = 'prop_cctv_cam_06a',
    ['security_cam_05'] = 'ba_prop_battle_cctv_cam_01b',
    ['security_cam_06'] = 'prop_cctv_cam_01b',
    ['security_cam_07'] = 'ch_prop_ch_cctv_cam_02a',
    ['security_cam_08'] = 'prop_cctv_cam_04c',
    ['security_cam_09'] = 'prop_cctv_cam_03a',
    ['security_cam_10'] = 'ch_prop_ch_cctv_cam_01a',
    ['security_cam_11'] = 'prop_cctv_cam_01a',
    ['security_cam_12'] = 'prop_cctv_cam_05a',
    ['security_cam_13'] = 'prop_cctv_cam_07a',
    ['security_cam_14'] = 'prop_cctv_cam_04b',
    ['security_cam_15'] = 'tr_prop_tr_camhedz_cctv_01a',
    ['security_cam_16'] = 'prop_cctv_cam_02a',
    ['security_cam_17'] = 'prop_cctv_cam_04a',
    ['cctv_cam_01'] = 'm24_1_prop_m24_1_carrier_bank_cctv_02',
    ['cctv_cam_02'] = 'xm_prop_x17_cctv_01a',
    ['cctv_cam_03'] = 'prop_cctv_pole_02',
    ['cctv_cam_04'] = 'm24_1_prop_m24_1_carrier_bank_cctv_01',
    ['cctv_cam_05'] = 'prop_cctv_pole_04',
    ['cctv_cam_06'] = 'xm_prop_x17_server_farm_cctv_01',
    ['cctv_cam_07'] = 'prop_cctv_pole_03',
    ['cctv_cam_08'] = 'p_cctv_s',
    ['cctv_cam_09'] = 'hei_prop_bank_cctv_02',
}

-- Camera types
Camera.types = {
    bodycam = 'bodycam',
    static = 'static'
}

-- Create a new instance of a camera
---@param camId string Unique identifier for the camera
---@param camType string Type of camera ('bodycam' or 'static')
---@param camLabel string Display label for the camera
---@param options table Additional options based on camera type
---@return table? Camera instance or nil if creation failed
function Camera.new(camId, camType, camLabel, options)
    if not camId or not camType then
        ps.error('Camera.new: camId and camType are required')
        return nil
    end

    if not Camera.types[camType] and camType ~= Camera.types.bodycam and camType ~= Camera.types.static then
        ps.error('Camera.new: Invalid camera type. Must be "bodycam" or "static"')
        return nil
    end

    local newCameraInstance = {
        camId = camId,
        camType = camType,
        camLabel = camLabel or 'Unnamed Camera',
        isSpawned = false,
        activeViewers = {},
        createdAt = os.time()
    }

    options = options or {}

    if camType == Camera.types.bodycam then
        newCameraInstance.playerId = options.playerId or nil
        newCameraInstance.note = options.note or ''
    elseif camType == Camera.types.static then
        newCameraInstance.model = options.model or 'security_cam_03'
        newCameraInstance.coords = options.coords or vector3(0.0, 0.0, 0.0)
        newCameraInstance.rotation = options.rotation or vector3(0.0, 0.0, 0.0)
        newCameraInstance.image = options.image or nil
        newCameraInstance.canRotate = options.canRotate ~= false -- Default to true
        newCameraInstance.isOnline = options.isOnline ~= false -- Default to true
        newCameraInstance.spawnsModel = options.spawnsModel ~= false -- Default to true (spawn model for new cameras)
        newCameraInstance.camTypeDb = options.camTypeDb or nil -- Database camera type
        newCameraInstance.entityId = nil -- Will be set when spawned
        -- health/destruction should be tracked client-side and synced if needed

        -- Validate model exists
        if not Camera.models[newCameraInstance.model] then
            ps.warn('Camera.new: Unknown model "' .. newCameraInstance.model .. '", using default')
            newCameraInstance.model = 'security_cam_03'
        end
    end

    --ps.debug('Camera.new: Creating new camera instance with ID ' .. camId)
    setmetatable(newCameraInstance, Camera)
    return newCameraInstance
end

-- Get the actual model hash for static cameras
---@return string? Model hash or nil if not applicable
function Camera:getModelHash()
    if self.camType == Camera.types.static then
        return Camera.models[self.model] or Camera.models['security_cam_03']
    end
    return nil
end

-- Spawn the camera
---@return boolean Success status
function Camera:spawn()
    if self.camType == Camera.types.bodycam then
        if self.playerId then
            -- bodycam item checks handled in backend/bodycams.lua
            self.isSpawned = true
            ps.debug('Camera:spawn - Bodycam marked as available for player ' .. self.playerId)
            return true
        end
        return false
    elseif self.camType == Camera.types.static then
        if self.isSpawned then
            ps.warn('Camera:spawn - Camera ' .. self.camId .. ' is already spawned')
            return true
        end

        local modelName = self:getModelHash()
        if not modelName then
            ps.error('Camera:spawn - Could not get model hash for camera ' .. self.camId)
            return false
        end

        local modelHash = GetHashKey(modelName)
        -- ps.debug('Camera:spawn - Requesting model: ' .. modelName .. ' (hash: ' .. modelHash .. ')')
        -- ps.debug('Camera:spawn - Spawning at coordinates: ' .. tostring(self.coords))
        -- ps.debug('Camera:spawn - Spawning with rotation: ' .. tostring(self.rotation))

        -- Create the object
        local entity = CreateObject(modelHash, self.coords.x, self.coords.y, self.coords.z, true, true, false)

        if not entity or entity == 0 then
            ps.error('Camera:spawn - Failed to create entity for camera ' .. self.camId)
            return false
        end

        SetEntityCoords(entity, self.coords.x, self.coords.y, self.coords.z, true, true, true, false)
        SetEntityRotation(entity, self.rotation.x, self.rotation.y, self.rotation.z, 2, true)
        FreezeEntityPosition(entity, true)

        -- cam properties should be set on the client after spawn

        -- network wait to ensure entity exists before returning
        local networkingTimeout = 0
        while not DoesEntityExist(entity) and networkingTimeout < 50 do
            Wait(50)
            networkingTimeout = networkingTimeout + 1
        end

        if networkingTimeout >= 50 then
            ps.error('Camera:spawn - Entity failed to network properly after timeout for camera ' .. self.camId)
            DeleteEntity(entity)
            return false
        end

        -- debug info
        -- local actualPos = GetEntityCoords(entity)
        -- local actualRot = GetEntityRotation(entity, 2)
        -- ps.debug('Camera:spawn - Entity actual position after creation: ' .. tostring(actualPos))
        -- ps.debug('Camera:spawn - Entity actual rotation after creation: ' .. tostring(actualRot))

        -- Store the entity ID and register in global registry
        self.entityId = entity
        self.isSpawned = true
        spawnedCameras[self.camId] = self

        return true
    end
    return false
end

-- Despawn the camera
---@return boolean Success status
function Camera:despawn()
    if self.camType == Camera.types.bodycam then
        self.isSpawned = false -- For bodycams, just mark as not spawned
        ps.debug('Camera:despawn - Bodycam removed for player ' .. (self.playerId or 'unknown'))
        return true
    elseif self.camType == Camera.types.static then
        if not self.isSpawned then
            --ps.warn('Camera:despawn - Camera ' .. self.camId .. ' is not spawned')
            return true
        end

        -- Deactivate all viewers
        self:deactivateAll()

        -- Delete the entity if it exists
        if self.entityId and DoesEntityExist(self.entityId) then
            --ps.debug('Camera:despawn - Deleting entity ' .. self.entityId .. ' for camera ' .. self.camId)
            DeleteEntity(self.entityId)
        end

        spawnedCameras[self.camId] = nil
        self.entityId = nil
        self.isSpawned = false
        --ps.debug('Camera:despawn - Despawned static camera ' .. self.camId)
        return true
    end
    return false
end

-- Activate camera viewing for a specific player
---@param playerId number Player server ID who wants to view the camera
---@return boolean Success status
function Camera:activate(playerId)
    ps.debug('Camera:activate called for player:', playerId, 'on camera:', self.camId)
    if not playerId then
        ps.error('Camera:activate - playerId is required')
        return false
    end

    if self.camType == Camera.types.bodycam then
        -- Check if the bodycam owner is online and has the item
        if not self.playerId or not GetPlayerPed(self.playerId) then
            ps.warn('Camera:activate - Bodycam owner is not online')
            return false
        end

        -- bodycam power/permission checks handled in backend/bodycams.lua

        if not self.isSpawned then
            ps.warn('Camera:activate - Bodycam is not available')
            return false
        end

    elseif self.camType == Camera.types.static then
        if not self.isSpawned then
            ps.warn('Camera:activate - Static camera is not spawned')
            return false
        end
    end

    -- Add player to active viewers if not already viewing
    if not self.activeViewers[playerId] then
        self.activeViewers[playerId] = {
            startTime = os.time(),
            playerName = ps.getPlayerName(playerId) or 'Unknown'
        }
        ps.debug('Camera:activate - Player ' .. playerId .. ' started viewing camera ' .. self.camId)

        TriggerClientEvent(resourceName..':client:startCameraView', playerId, self:getData())

        -- Track the camera this player is viewing
        playerViewingCamera[playerId] = self.camId

        return true
    else
        ps.warn('Camera:activate - Player ' .. playerId .. ' is already viewing camera ' .. self.camId)
        return false
    end
end

-- Deactivate camera viewing for a specific player
---@param playerId number Player server ID who wants to stop viewing
---@return boolean Success status
function Camera:deactivate(playerId)
    if not playerId then
        ps.error('Camera:deactivate - playerId is required')
        return false
    end

    if self.activeViewers[playerId] then
        local viewDuration = os.time() - self.activeViewers[playerId].startTime
        ps.debug('Camera:deactivate - Player ' .. playerId .. ' stopped viewing camera ' .. self.camId .. ' after ' .. viewDuration .. ' seconds')

        self.activeViewers[playerId] = nil

        TriggerClientEvent(resourceName..':client:stopCameraView', playerId)

        -- Remove the camera tracking for this player
        playerViewingCamera[playerId] = nil

        return true
    else
        ps.warn('Camera:deactivate - Player ' .. playerId .. ' is not viewing camera ' .. self.camId)
        return false
    end
end

-- Deactivate all viewers
---@return number Number of viewers deactivated
function Camera:deactivateAll()
    local count = 0
    -- Collect IDs first to avoid mutating table during iteration
    local viewerIds = {}
    for playerId, _ in pairs(self.activeViewers) do
        viewerIds[#viewerIds + 1] = playerId
    end
    for _, playerId in ipairs(viewerIds) do
        self:deactivate(playerId)
        count = count + 1
    end
    return count
end

-- Check if camera has any active viewers
---@return boolean Has viewers
function Camera:hasViewers()
    return next(self.activeViewers) ~= nil
end

-- Get the number of active viewers
---@return number Viewer count
function Camera:getViewerCount()
    local count = 0
    for _ in pairs(self.activeViewers) do
        count = count + 1
    end
    return count
end

-- Check if a specific player is viewing this camera
---@param playerId number Player server ID
---@return boolean Is viewing
function Camera:isPlayerViewing(playerId)
    return self.activeViewers[playerId] ~= nil
end

-- Toggle bodycam power (for inventory item integration)
---@param playerId number Player who owns the bodycam
---@param powered boolean Power state
---@return boolean Success status
function Camera:toggleBodycamPower(playerId, powered)
    if self.camType ~= Camera.types.bodycam then
        ps.error('Camera:toggleBodycamPower - Can only be used on bodycams')
        return false
    end

    if self.playerId ~= playerId then
        ps.error('Camera:toggleBodycamPower - Player does not own this bodycam')
        return false
    end

    if powered then
        return self:spawn()
    else
        self:deactivateAll()
        return self:despawn()
    end
end

-- Get camera information as a table
---@return table Camera data
function Camera:getData()
    local data = {
        camId = self.camId,
        camType = self.camType,
        camLabel = self.camLabel,
        isSpawned = self.isSpawned,
        activeViewers = {},
        viewerCount = 0,
        createdAt = self.createdAt
    }

    -- Get viewer information without exposing the full table
    for playerId, viewerInfo in pairs(self.activeViewers) do
        data.viewerCount = data.viewerCount + 1
        table.insert(data.activeViewers, {
            playerId = playerId,
            playerName = viewerInfo.playerName,
            viewingFor = os.time() - viewerInfo.startTime
        })
    end

    if self.camType == Camera.types.bodycam then
        data.playerId = self.playerId
        data.note = self.note
        data.playerName = self.playerId and (ps.getPlayerName(self.playerId) or GetPlayerName(self.playerId)) or 'Unknown'
    elseif self.camType == Camera.types.static then
        data.model = self.model
        data.modelHash = self:getModelHash()
        data.coords = self.coords
        data.rotation = self.rotation
        data.entityId = self.entityId

        -- Convert entity ID to network ID for client-server communication
        if self.entityId and DoesEntityExist(self.entityId) then
            data.networkId = NetworkGetNetworkIdFromEntity(self.entityId)
            ps.debug('Camera:getData - Entity ID:', self.entityId, 'Network ID:', data.networkId)
        else
            data.networkId = nil
            ps.warn('Camera:getData - Entity does not exist, cannot get network ID')
        end
    end

    return data
end

-- Update camera properties
---@param updates table Properties to update
function Camera:update(updates)
    if not updates then return end

    -- Common properties
    if updates.camLabel then self.camLabel = updates.camLabel end

    if self.camType == Camera.types.bodycam then
        if updates.note then self.note = updates.note end
        if updates.playerId then self.playerId = updates.playerId end
    elseif self.camType == Camera.types.static then
        if updates.coords then self.coords = updates.coords end
        if updates.rotation then self.rotation = updates.rotation end
        if updates.model and Camera.models[updates.model] then
            local oldModel = self.model
            self.model = updates.model
            -- If model changes and camera is spawned, it needs to be respawned
            if self.isSpawned and oldModel ~= self.model then
                ps.debug('Camera:update - Model changed, respawning camera')
                self:despawn()
                self:spawn()
            end
        end
    end
end

-- Check if camera is valid and functional
---@return boolean Valid status
function Camera:isValid()
    if self.camType == Camera.types.bodycam then
        return self.playerId ~= nil and GetPlayerPed(self.playerId) ~= 0
    elseif self.camType == Camera.types.static then
        return self.coords ~= nil and Camera.models[self.model] ~= nil
    end
    return false
end

-- Destroy the camera instance
function Camera:destroy()
    self:deactivateAll()
    self:despawn()
    -- Clear all references
    for k, _ in pairs(self) do
        self[k] = nil
    end
end

-- Static utility functions for the Camera class

-- Get all available camera models
---@return table List of available models
function Camera.getAvailablemodels()
    local models = {}
    for key, hash in pairs(Camera.models) do
        table.insert(models, {
            key = key,
            hash = hash,
            name = key:gsub('_', ' '):gsub('%b()', ''):upper()
        })
    end
    return models
end

-- Validate camera type
---@param camType string Camera type to validate
---@return boolean Valid status
function Camera.isValidType(camType)
    return camType == Camera.types.bodycam or camType == Camera.types.static
end

-- Create a bodycam instance
---@param camId string Unique camera ID
---@param playerId number Player server ID
---@param label string? Camera label
---@param note string? Additional notes
---@return table? Camera instance
function Camera.createBodycam(camId, playerId, label, note)
    return Camera.new(camId, Camera.types.bodycam, label or 'Bodycam', {
        playerId = playerId,
        note = note or '',
    })
end

-- Create a static camera instance
---@param camId string Unique camera ID
---@param coords vector3 Camera position
---@param rotation vector3? Camera rotation (default: 0,0,0)
---@param label string? Camera label
---@param model string? Camera model key (default: 'security_cam_03')
---@return table? Camera instance
function Camera.createStatic(camId, coords, rotation, label, model)
    return Camera.new(camId, Camera.types.static, label or 'Static Camera', {
        coords = coords,
        rotation = rotation or vector3(0.0, 0.0, 0.0),
        model = model or 'security_cam_03',
    })
end

-- Database utility funcs --------------------------------

-- Save camera to database (for static cameras)
---@return boolean Success status
function Camera:saveToDatabase()
    if self.camType ~= Camera.types.static then
        ps.warn('Camera:saveToDatabase - Only static cameras can be saved to database')
        return false
    end

    local query = [[
        INSERT INTO mdt_cameras (cam_id, cam_label, cam_type, model, coords, rotation, image, can_rotate, is_online, spawns_model, created_by)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE
        cam_label = VALUES(cam_label), cam_type = VALUES(cam_type), model = VALUES(model), coords = VALUES(coords),
        rotation = VALUES(rotation), image = VALUES(image), can_rotate = VALUES(can_rotate), is_online = VALUES(is_online), spawns_model = VALUES(spawns_model)
    ]]

    local success = MySQL.insert.await(query, {
        self.camId,
        self.camLabel,
        self.camTypeDb or 'placed',
        self.model,
        json.encode({x = self.coords.x, y = self.coords.y, z = self.coords.z}),
        json.encode({x = self.rotation.x, y = self.rotation.y, z = self.rotation.z}),
        self.image or '',
        self.canRotate,
        self.isOnline,
        self.spawnsModel,
        self.createdBy
    })

    if success then
        ps.debug('Camera:saveToDatabase - Saved camera ' .. self.camId .. ' to database')
        return true
    else
        ps.error('Camera:saveToDatabase - Failed to save camera ' .. self.camId .. ' to database')
        return false
    end
end

-- Delete camera from database
---@return boolean Success status
function Camera:deleteFromDatabase()
    if self.camType ~= Camera.types.static then
        ps.warn('Camera:deleteFromDatabase - Only static cameras can be deleted from database')
        return false
    end

    local query = "DELETE FROM mdt_cameras WHERE cam_id = ?"
    local success = MySQL.query.await(query, { self.camId })

    if success then
        ps.debug('Camera:deleteFromDatabase - Deleted camera ' .. self.camId .. ' from database')
        return true
    else
        ps.error('Camera:deleteFromDatabase - Failed to delete camera ' .. self.camId .. ' from database')
        return false
    end
end

-- Load all static cameras from database and spawn them
---@return table List of loaded cameras
function Camera.loadAllFromDatabase()
    local cameras = {}

    local query = "SELECT * FROM mdt_cameras"
    local results = MySQL.query.await(query)

    if not results then
        ps.debug('Camera.loadAllFromDatabase - No cameras found in database')
        return cameras
    end

    for _, row in ipairs(results) do
        local coords = json.decode(row.coords)
        local rotation = json.decode(row.rotation)

        local camera = Camera.createStatic(
            row.cam_id,
            vector3(coords.x, coords.y, coords.z),
            vector3(rotation.x, rotation.y, rotation.z),
            row.cam_label,
            row.model
        )

        if camera then
            camera.camTypeDb = row.cam_type
            camera.image = row.image
            camera.canRotate = row.can_rotate
            camera.isOnline = row.is_online
            camera.spawnsModel = row.spawns_model
            camera.createdAt = row.created_at
            camera.createdBy = row.created_by

            if camera.camTypeDb == 'placed' or camera.spawnsModel then
                camera:spawn()
                --ps.debug('Camera.loadAllFromDatabase - Loaded and spawned physical camera ' .. row.cam_id .. ' (type: ' .. camera.camTypeDb .. ')')
            else
                camera.isSpawned = true
                --ps.debug('Camera.loadAllFromDatabase - Loaded virtual camera ' .. row.cam_id .. ' (type: ' .. camera.camTypeDb .. ', no model spawned)')
            end

            cameras[row.cam_id] = camera
            spawnedCameras[row.cam_id] = camera
        else
            ps.error('Camera.loadAllFromDatabase - Failed to create camera ' .. row.cam_id)
        end
    end

    --ps.info('Camera.loadAllFromDatabase - Loaded ' .. #cameras .. ' cameras from database')
    return cameras
end

-- Server event handlers for client menu actions ----------------------------------

-- Handle camera creation request from client
RegisterNetEvent(resourceName .. ':server:createStaticCamera', function(cameraData)
    local playerId = source
    if not CheckAuth(playerId) then return end

    ps.debug('Creating static camera for player:', playerId)
    ps.debug('Received camera data:')
    ps.debug('  camId: ' .. tostring(cameraData.camId))
    ps.debug('  coords: ' .. tostring(cameraData.coords))
    ps.debug('  rotation: ' .. tostring(cameraData.rotation))

    if not cameraData or type(cameraData) ~= 'table' then
        ps.error('Camera creation failed - invalid data from player:', playerId)
        return
    end

    -- Validate required fields
    if not cameraData.camId or not cameraData.camLabel or not cameraData.model or not cameraData.coords then
        ps.error('Camera creation failed - missing required fields for player:', playerId)
        return
    end

    -- Check if camera ID already exists
    if spawnedCameras[cameraData.camId] then
        ps.error('Camera creation failed - camera ID already exists:', cameraData.camId, 'for player:', playerId)
        return
    end

    -- Create the camera
    local camera = Camera.createStatic(
        cameraData.camId,
        cameraData.coords,
        cameraData.rotation,
        cameraData.camLabel,
        cameraData.model
    )

    -- Update camera with additional properties if created successfully
    if camera then
        -- Set creation metadata
        camera.createdBy = ps.getIdentifier(playerId)
        camera.createdAt = os.time() * 1000 -- Convert to milliseconds

        -- Set camera type and spawning behavior for player-placed cameras
        camera.camTypeDb = 'placed'
        camera.spawnsModel = true
        camera.canRotate = true
        camera.isOnline = true
    end

    if camera then
        -- Add camera to global registry
        spawnedCameras[cameraData.camId] = camera

        -- Spawn the camera immediately
        local spawnSuccess = camera:spawn()
        if spawnSuccess then
            ps.info('Camera created and spawned successfully:', cameraData.camId)
        else
            ps.warn('Camera created but failed to spawn:', cameraData.camId)
        end

        -- Save to database
        local dbSaveSuccess = camera:saveToDatabase()
        if dbSaveSuccess then
            ps.info('Camera saved to database successfully:', cameraData.camId)
        else
            ps.error('Camera created but failed to save to database:', cameraData.camId)
        end

        ps.debug('Camera created successfully:', cameraData.camId)
    else
        ps.error('Failed to create camera:', cameraData.camId)
    end
end)

-- Handle camera list request from client
RegisterNetEvent(resourceName .. ':server:requestCameraList', function()
    local playerId = source
    if not CheckAuth(playerId) then return end
    ps.debug('Sending camera list to player:', playerId)

    local cameraList = {}
    for camId, camera in pairs(spawnedCameras) do
        table.insert(cameraList, {
            camId = camera.camId,
            camLabel = camera.camLabel,
            model = camera.model,
            coords = camera.coords,
            rotation = camera.rotation,
            isSpawned = camera.isSpawned,
            viewerCount = camera:getViewerCount()
        })
    end

    TriggerClientEvent(resourceName .. ':client:receiveCameraList', playerId, cameraList)
end)

-- Handle camera spawn request from client
RegisterNetEvent(resourceName .. ':server:spawnCamera', function(camId)
    local playerId = source
    if not CheckAuth(playerId) then return end
    ps.debug('Spawning camera for player:', playerId, 'Camera ID:', camId)

    local camera = spawnedCameras[camId]
    if not camera then
        ps.error('Camera spawn failed - camera not found:', camId, 'for player:', playerId)
        return
    end

    if camera.isSpawned then
        ps.error('Camera spawn failed - camera already spawned:', camId, 'for player:', playerId)
        return
    end

    local success = camera:spawn()
    if success then
        ps.info('Camera spawned successfully:', camId, 'for player:', playerId)
    else
        ps.error('Camera spawn failed - could not spawn camera:', camId, 'for player:', playerId)
    end
end)

-- Handle camera despawn request from client
RegisterNetEvent(resourceName .. ':server:despawnCamera', function(camId)
    local playerId = source
    if not CheckAuth(playerId) then return end
    ps.debug('Despawning camera for player:', playerId, 'Camera ID:', camId)

    local camera = spawnedCameras[camId]
    if not camera then
        ps.error('Camera despawn failed - camera not found:', camId, 'for player:', playerId)
        return
    end

    if not camera.isSpawned then
        ps.error('Camera despawn failed - camera is not spawned:', camId, 'for player:', playerId)
        return
    end

    camera:despawn()
    ps.info('Camera despawned successfully:', camId, 'for player:', playerId)
end)

-- Handle camera activation request from client
RegisterNetEvent(resourceName .. ':server:activateCamera', function(camId)
    local playerId = source
    if not CheckAuth(playerId) then return end
    ps.debug('Activating camera for player:', playerId, 'Camera ID:', camId)

    local camera = spawnedCameras[camId]
    if not camera then
        ps.error('Camera activation failed - camera not found:', camId, 'for player:', playerId)
        return
    end

    if not camera.isSpawned then
        ps.error('Camera activation failed - camera must be spawned first:', camId, 'for player:', playerId)
        return
    end

    -- Stop viewing any current camera first
    if playerViewingCamera[playerId] then
        local currentCam = spawnedCameras[playerViewingCamera[playerId]]
        if currentCam then
            currentCam:deactivate(playerId)
        end
        TriggerClientEvent(resourceName .. ':client:stopCameraView', playerId)
    end

    local success = camera:activate(playerId)
    if success then
        -- Track which camera this player is viewing (activate() already fires startCameraView to client)
        playerViewingCamera[playerId] = camId
        ps.info('Player ' .. playerId .. ' is now viewing camera: ' .. camId .. ' (Entity: ' .. tostring(camera.entityId) .. ')')
    else
        ps.error('Camera activation failed - could not activate camera:', camId, 'for player:', playerId)
    end
end)

-- Handle camera deactivation request from client
RegisterNetEvent(resourceName .. ':server:deactivateCamera', function(camId)
    local playerId = source
    if not CheckAuth(playerId) then return end
    ps.debug('Deactivating camera for player:', playerId, 'Camera ID:', camId)

    -- Handle special case where client sends 'current' to deactivate whatever they're viewing
    if camId == 'current' then
        camId = playerViewingCamera[playerId]
        if not camId then
            ps.error('Camera deactivation failed - player is not viewing any camera:', playerId)
            return
        end
    end

    local camera = spawnedCameras[camId]
    if not camera then
        ps.error('Camera deactivation failed - camera not found:', camId, 'for player:', playerId)
        return
    end

    local success = camera:deactivate(playerId)
    if success then
        -- Clear tracking
        playerViewingCamera[playerId] = nil

        -- Stop camera view on client
        TriggerClientEvent(resourceName .. ':client:stopCameraView', playerId)
        ps.info('Player ' .. playerId .. ' stopped viewing camera: ' .. camId)
    else
        ps.error('Camera deactivation failed - player was not viewing this camera:', camId, 'for player:', playerId)
    end
end)

-- Handle camera deletion request from client
RegisterNetEvent(resourceName .. ':server:deleteCamera', function(camId)
    local playerId = source
    if not CheckAuth(playerId) then return end
    ps.debug('Deleting camera for player:', playerId, 'Camera ID:', camId)

    local camera = spawnedCameras[camId]
    if not camera then
        ps.error('Camera deletion failed - camera not found:', camId, 'for player:', playerId)
        return
    end

    -- Deactivate for all viewers first
    for viewerId, _ in pairs(camera.activeViewers) do
        camera:deactivate(viewerId)
        TriggerClientEvent(resourceName .. ':client:stopCameraView', viewerId)
        ps.info('Deactivated camera for viewer:', viewerId)
        ps.info('Camera Deleted: Camera "' .. camera.camLabel .. '" was deleted')
    end

    -- Despawn and destroy
    camera:despawn()

    -- Remove from database
    local dbDeleteSuccess = camera:deleteFromDatabase()
    if dbDeleteSuccess then
        ps.info('Camera removed from database successfully:', camId)
    else
        ps.error('Camera despawned but failed to remove from database:', camId)
    end

    camera:destroy()

    -- Remove from spawned cameras registry
    spawnedCameras[camId] = nil

    ps.info('Camera deleted successfully:', camId, 'for player:', playerId)
end)

-- Handle camera update request from client
ps.registerCallback(resourceName .. ':server:updateCamera', function(source, updateData)
    local playerId = source
    ps.debug('Updating camera for player:', playerId, 'Data:', updateData)

    if not updateData or type(updateData) ~= 'table' then
        ps.error('Camera update failed - invalid data from player:', playerId)
        return { success = false, error = 'Invalid update data' }
    end

    -- Validate required fields
    if not updateData.camId then
        ps.error('Camera update failed - missing camera ID for player:', playerId)
        return { success = false, error = 'Missing camera ID' }
    end

    -- Check if camera exists
    local camera = spawnedCameras[updateData.camId]
    if not camera then
        ps.error('Camera update failed - camera not found:', updateData.camId, 'for player:', playerId)
        return { success = false, error = 'Camera not found' }
    end

    -- Store old position for comparison
    local oldCoords = camera.coords
    local oldModel = camera.model
    local wasSpawned = camera.isSpawned

    -- Update camera properties
    local updates = {}
    if updateData.camLabel then updates.camLabel = updateData.camLabel end
    if updateData.model then updates.model = updateData.model end
    if updateData.coords then updates.coords = updateData.coords end
    if updateData.rotation then updates.rotation = updateData.rotation end

    camera:update(updates)

    -- If camera was spawned and position/model changed, respawn it
    if wasSpawned and (updateData.coords or updateData.model) then
        if updateData.coords and (oldCoords.x ~= updateData.coords.x or oldCoords.y ~= updateData.coords.y or oldCoords.z ~= updateData.coords.z) then
            ps.debug('Camera position changed, respawning camera:', updateData.camId)
            camera:despawn()
            camera:spawn()
        elseif updateData.model and oldModel ~= updateData.model then
            ps.debug('Camera model changed, respawning camera:', updateData.camId)
            camera:despawn()
            camera:spawn()
        end
    end

    camera:saveToDatabase()

    ps.info('Camera updated successfully:', updateData.camId, 'for player:', playerId)
    return { success = true }
end)

-- Global utility functions -------------------

-- Get the number of spawned cameras
function GetSpawnedCameraCount()
    local count = 0
    for _, camera in pairs(spawnedCameras) do
        if camera.isSpawned then
            count = count + 1
        end
    end
    return count
end

-- Get all spawned cameras
function GetAllSpawnedCameras()
    local cameras = {}
    for camId, camera in pairs(spawnedCameras) do
        if camera.isSpawned then
            cameras[camId] = camera
        end
    end
    return cameras
end

-- Clean up all cameras
function CleanupAllCameras()
    local count = 0
    local viewerCount = 0

    for camId, camera in pairs(spawnedCameras) do
        if camera then
            -- Count and deactivate all viewers
            local activeViewers = camera:getViewerCount()
            if activeViewers > 0 then
                ps.debug('Deactivating ' .. activeViewers .. ' viewers for camera: ' .. camId)
                camera:deactivateAll()
                viewerCount = viewerCount + activeViewers

                -- Send stop camera view to all clients who might be viewing
                for playerId in pairs(camera.activeViewers or {}) do
                    TriggerClientEvent(resourceName .. ':client:stopCameraView', playerId)
                end
            end

            -- Despawn if spawned
            if camera.isSpawned then
                camera:despawn()
                count = count + 1
            end

            -- Destroy the camera instance
            camera:destroy()
        end
    end

    -- Clear all global tracking
    spawnedCameras = {}
    playerViewingCamera = {}

    --ps.debug('Cleaned up ' .. count .. ' cameras and ' .. viewerCount .. ' active viewers')
    return count
end

-- Callbacks ----------------------------

-- Callback to get spawned cameras for the frontend
ps.registerCallback(resourceName .. ':server:getCameras', function(source)
    local src = source
    if not CheckAuth(src) then
        return {}
    end

    local cameraList = {}
    for camId, camera in pairs(spawnedCameras) do
        table.insert(cameraList, {
            id = camId,
            label = camera.camLabel,
            type = camera.camTypeDb or camera.camType,
            isOnline = camera.isOnline ~= false,
            image = camera.image or '',
            coords = camera.coords,
            rotation = camera.rotation,
            model = camera.model,
            viewerCount = camera:getViewerCount()
        })
    end

    return cameraList
end)

-- Callback to start viewing a specific camera
ps.registerCallback(resourceName .. ':server:viewCamera', function(source, cameraId)
    local src = source
    if not CheckAuth(src) then
        return { success = false, error = "Unauthorized" }
    end

    local camera = spawnedCameras[cameraId]
    if not camera then
        return { success = false, error = "Camera not found" }
    end

    local success = camera:activate(src)
    ps.debug('Camera activation success:', success, 'for camera:', cameraId, 'by source:', src)
    if success then
        return {
            success = true,
            camera = {
                id = camera.camId,
                label = camera.camLabel,
                coords = camera.coords,
                rotation = camera.rotation
            }
        }
    else
        return { success = false, error = "Failed to activate camera" }
    end
end)

-- Callback to get available camera models
ps.registerCallback(resourceName .. ':server:getCameraModels', function(source)
    local models = {}
    for key, hash in pairs(Camera.models) do
        -- Format the label nicely
        local displayName = key:gsub('_', ' '):upper()
        displayName = displayName:gsub('CAM', 'Camera')
        displayName = displayName:gsub('CCTV', 'CCTV')

        table.insert(models, {
            value = key,
            label = displayName .. ' (' .. hash .. ')',
            model = hash
        })
    end

    -- Sort models alphabetically by label for better UX
    table.sort(models, function(a, b) return a.label < b.label end)

    ps.debug('Providing ' .. #models .. ' camera models to client ' .. source)
    return models
end)

-- Callback to validate camera model
ps.registerCallback(resourceName .. ':server:validateCameraModel', function(source, modelKey)
    local isValid = Camera.models[modelKey] ~= nil
    ps.debug('Validating camera model "' .. tostring(modelKey) .. '" for client ' .. source .. ': ' .. tostring(isValid))
    return isValid
end)

-- Cleanup ---------------------------------------

-- Resource start - load cameras from database
AddEventHandler('onResourceStart', function(startedResource)
    if startedResource == GetCurrentResourceName() then
        Wait(1000)

        local loadedCameras = Camera.loadAllFromDatabase()
        local count = 0
        for _ in pairs(loadedCameras) do count = count + 1 end

        ps.debug('Loaded ' .. count .. ' cameras from database')
    end
end)

-- Resource stop cleanup
AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        CleanupAllCameras()
    end
end)

-- Clean up player from viewing tracking when they disconnect
AddEventHandler('playerDropped', function(reason)
    local playerId = source

    -- Stop viewing any camera they might be watching
    if playerViewingCamera[playerId] then
        local camId = playerViewingCamera[playerId]
        local camera = spawnedCameras[camId]
        if camera then
            camera:deactivate(playerId)
        end
        playerViewingCamera[playerId] = nil
        ps.debug('Cleaned up camera viewing for disconnected player:', playerId)
    end
end)

