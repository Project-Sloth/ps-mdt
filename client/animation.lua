local tabletProp = nil
local isPlayingTabletAnim = false
local animDict = Config.Animation and Config.Animation.Dict or 'amb@world_human_tourist_map@male@base'
local animName = Config.Animation and Config.Animation.Name or 'base'
local propModel = 'ps-mdt'

-- Helper to always get current ped (never stale)
local function getPed()
    return PlayerPedId()
end

-- Options ----------------------------------

local propOptions = {
    xPos = 0.0, -- X-axis offset from the center of entity2
    yPos = -0.03, -- Y-axis offset from the center of entity2
    zPos = 0.0, -- Z-axis offset from the center of entity2
    xRot = 20.0, -- X-axis rotation
    yRot = -90.0, -- Y-axis rotation
    zRot = 0.0, -- Z-axis rotation
    p9 = true, -- Unknown
    useSoftPinning = true, -- If set to false attached entity will not detach when fixed
    collision = false, -- Controls collision between the two entities
    isPed = true, -- Pitch doesnt work when false and roll will only work on negative numbers (only peds)
    rotationOrder = 1, -- The order in which the rotation is applied
    syncRot = true -- If false it ignores entity rotation
}

local animOptions = {
        animDict = animDict, -- The animation dictionary
        animName = animName, -- The animation name
        blendInSpeed = 3.0, -- The speed at which the animation blends in
        blendOutSpeed = 2.0, -- The speed at which the animation blends out
        duration = -1, -- The duration of the animation in milliseconds (-1 = loop)
        flag = 49, -- Animation flags (49 = loop with upper body, allow movement)
        playbackRate = 0, -- The playback rate (between 0.0 and 1.0)
        lockX = false, -- Lock X rotation
        lockY = false, -- Lock Y rotation
        lockZ = false -- Lock Z rotation
}

-- Animation Monitoring ---------------------------------

local monitoringThread = nil

-- Start animation monitoring
local function StartAnimationMonitoring()
    if monitoringThread then return end -- Already monitoring

    monitoringThread = CreateThread(function()
        while MDTOpen and isPlayingTabletAnim do
            if not IsEntityPlayingAnim(getPed(), animDict, animName, 3) then
                RestartTabletAnimation()
            end
            Wait(2000)
        end
        monitoringThread = nil
    end)
end

-- Stop animation monitoring
local function StopAnimationMonitoring()
    if monitoringThread then
        monitoringThread = nil
    end
end

-- Prop Handling ---------------------------------

-- Create and attach tablet prop
local function CreateTabletProp()
    local ped = getPed()
    local coords = GetEntityCoords(ped)
    local propHash = GetHashKey(propModel)

    if not ps.requestModel(propModel) then
        ps.warn('Failed to load tablet prop model')
        return false
    end

    tabletProp = CreateObject(propHash, coords.x, coords.y, coords.z + 0.2, true, true, true)

    if not DoesEntityExist(tabletProp) then
        ps.warn('Failed to create tablet prop')
        SetModelAsNoLongerNeeded(propHash)
        return false
    end

    -- Attach prop to player
    local boneIndex = GetPedBoneIndex(ped, 28422)
    AttachEntityToEntity(
        tabletProp,
        ped,
        boneIndex,
        propOptions.xPos,
        propOptions.yPos,
        propOptions.zPos,
        propOptions.xRot,
        propOptions.yRot,
        propOptions.zRot,
        propOptions.p9,
        propOptions.useSoftPinning,
        propOptions.collision,
        propOptions.isPed,
        propOptions.rotationOrder,
        propOptions.syncRot
    )

    -- Clean up model from memory
    SetModelAsNoLongerNeeded(propHash)

    ps.debug('Tablet prop created and attached')
    return true
end

-- Function to destroy tablet prop
local function DestroyTabletProp()
    if tabletProp and DoesEntityExist(tabletProp) then
        DeleteEntity(tabletProp)
        tabletProp = nil
        ps.debug('Tablet prop destroyed')
    end
end

-- Animation Handling ---------------------------------

-- Function to play tablet animation
function PlayTabletAnimation()
    if isPlayingTabletAnim then
        return
    end

    local ped = getPed()

    if not ps.requestAnim(animDict) then
        ps.debug('Failed to load tablet animation dictionary')
        return
    end

    if IsPedUsingAnyScenario(ped) or IsPedActiveInScenario(ped) then
        ClearPedTasksImmediately(ped)
    end

    if not CreateTabletProp() then
        RemoveAnimDict(animDict)
        return
    end

    TaskPlayAnim(
        ped,
        animOptions.animDict,
        animOptions.animName,
        animOptions.blendInSpeed,
        animOptions.blendOutSpeed,
        animOptions.duration,
        animOptions.flag,
        animOptions.playbackRate,
        animOptions.lockX,
        animOptions.lockY,
        animOptions.lockZ
    )

    RemoveAnimDict(animDict)
    isPlayingTabletAnim = true
    ps.debug('Tablet animation started')
    StartAnimationMonitoring()
end

-- Stop tablet animation
function StopTabletAnimation()
    if not isPlayingTabletAnim then return end

    StopAnimationMonitoring()
    ClearPedTasks(getPed())
    DestroyTabletProp()

    isPlayingTabletAnim = false
    ps.debug('Tablet animation stopped')
end

-- Check if tablet animation is playing
function IsPlayingTabletAnimation()
    return isPlayingTabletAnim
end

-- Restart tablet animation
function RestartTabletAnimation()
    if not isPlayingTabletAnim then return end

    local ped = getPed()

    if not ps.requestAnim(animDict) then
        ps.debug('Failed to load tablet animation dictionary for restart')
        return
    end

    TaskPlayAnim(
        ped,
        animOptions.animDict,
        animOptions.animName,
        animOptions.blendInSpeed,
        animOptions.blendOutSpeed,
        animOptions.duration,
        animOptions.flag,
        animOptions.playbackRate,
        animOptions.lockX,
        animOptions.lockY,
        animOptions.lockZ
    )

    RemoveAnimDict(animDict)
end

-- Event Handlers ---------------------------------

-- Cleanup on resource stop
AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    if isPlayingTabletAnim then
        StopTabletAnimation()
    end
end)
