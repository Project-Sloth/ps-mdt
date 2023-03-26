local mugshotInProgress, createdCamera, MugshotArray = false, 0, {}
local handle, board, board_scaleform, overlay, ped, pedcoords, x, y, z, r, suspectheading, suspectx, suspecty, suspectz, board_pos
local MugShots = {}

-- Mugshot location  ( Position is the default QBCore Prison Interior )
    x = 1828.69
    y = 2581.72
    z = 46.3
    r = {x = 0.0, y = 0.0, z = 92.23}
    suspectheading = 265.00
    suspectx = 1827.63
    suspecty = 2581.7
    suspectz = 44.89
    
-- Mugshot functions

local function TakeMugShot()
    exports['screenshot-basic']:requestScreenshotUpload(Config.Webhook, 'files[]', {encoding = 'jpg'}, function(data)
        local resp = json.decode(data)
        table.insert(MugshotArray, resp.attachments[1].url)
    end)
end

local function PhotoProcess(ped)
    local rotation = suspectheading
    for photo = 1, Config.MugPhotos, 1 do
        Wait(1500)
        TakeMugShot()
        PlaySoundFromCoord(-1, "SHUTTER_FLASH", x, y, z, "CAMERA_FLASH_SOUNDSET", true, 5, false)
        Wait(1500)
        rotation = rotation - 90.0
        SetEntityHeading(ped, rotation)
    end
end

local function MugShotCamera()
    if createdCamera ~= 0 then
        DestroyCam(createdCamera, false)
        createdCamera = 0
    end
    local cam = CreateCam("DEFAULT_SCRIPTED_CAMERA", true)
    SetCamCoord(cam, x, y, z)
    SetCamRot(cam, r.x, r.y, r.z, 2)
    RenderScriptCams(true, false, 0, true, true)
    Wait(250)
    createdCamera = cam
    CreateThread(function()
        FreezeEntityPosition(ped, true)
        SetPauseMenuActive(false)
        while mugshotInProgress do
            DisableAllControlActions(0)
            EnableControlAction(0, 249, true)
            EnableControlAction(0, 46, true)
            Wait(1)
        end
    end)
end

local function CreateNamedRenderTargetForModel(name, model)
    local handle = 0
    if not IsNamedRendertargetRegistered(name) then
        RegisterNamedRendertarget(name, false)
    end
    if not IsNamedRendertargetLinked(model) then
        LinkNamedRendertarget(model)
    end
    if IsNamedRendertargetRegistered(name) then
        handle = GetNamedRendertargetRenderId(name)
    end
    return handle
end

local function LoadScaleform (scaleform)
    local handle = RequestScaleformMovie(scaleform)
    if handle ~= 0 then
        while not HasScaleformMovieLoaded(handle) do
            Wait(0)
        end
    end
    return handle
end

local function CallScaleformMethod (scaleform, method, ...)
    local t
    local args = { ... }
    BeginScaleformMovieMethod(scaleform, method)
    for k, v in ipairs(args) do
        t = type(v)
        if t == 'string' then
            PushScaleformMovieMethodParameterString(v)
        elseif t == 'number' then
            if string.match(tostring(v), "%.") then
                PushScaleformMovieFunctionParameterFloat(v)
            else
                PushScaleformMovieFunctionParameterInt(v)
            end
        elseif t == 'boolean' then
            PushScaleformMovieMethodParameterBool(v)
        end
    end
    EndScaleformMovieMethod()
end

local function PrepBoard()
    CreateThread(function()
        board_scaleform = LoadScaleform("mugshot_board_01")
        handle = CreateNamedRenderTargetForModel("ID_Text", `prop_police_id_text`)
        while handle do
            HideHudAndRadarThisFrame()
            SetTextRenderId(handle)
            Set_2dLayer(4)
            SetScriptGfxDrawBehindPausemenu(true)
            DrawScaleformMovie(board_scaleform, 0.405, 0.37, 0.81, 0.74, 255, 255, 255, 255, 0)
            SetScriptGfxDrawBehindPausemenu(false)
            SetTextRenderId(GetDefaultScriptRendertargetRenderId())
            SetScriptGfxDrawBehindPausemenu(true)
            SetScriptGfxDrawBehindPausemenu(false)
            Wait(0)
        end
    end)
end

local function MakeBoard()
    local title = "Bolingbroke Penitentiary"
    local center = Framework.GetPlayerFirstName().. " ".. Framework.GetPlayerLastName()
    local footer = Framework.GetPlayerCitizenId()
    local header = Framework.GetPlayerBirthDate()
    CallScaleformMethod(board_scaleform, 'SET_BOARD', title, center, footer, header, 0, 1337, 116)
end

local function PlayerBoard()
    RequestModel(`prop_police_id_board`)
    RequestModel(`prop_police_id_text`)
    while not HasModelLoaded(`prop_police_id_board`) or not HasModelLoaded(`prop_police_id_text`) do
        Wait(1)
    end
    board = CreateObject(`prop_police_id_board`, pedcoords.x, pedcoords.y, pedcoords.z, true, true, false)
    overlay = CreateObject(`prop_police_id_text`, pedcoords.x, pedcoords.y, pedcoords.z, true, true, false)
    AttachEntityToEntity(overlay, board, -1, 4103, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, false, false, false, false, 2, true) -- this is probably wrong. it looks like boneIndex is -1 and xPos is 4103
    SetModelAsNoLongerNeeded(`prop_police_id_board`)
    SetModelAsNoLongerNeeded(`prop_police_id_text`)
    SetCurrentPedWeapon(ped, `weapon_unarmed`, true)
    ClearPedWetness(ped)
    ClearPedBloodDamage(ped)
    AttachEntityToEntity(board, ped, GetPedBoneIndex(ped, 28422), 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, false, false, false, false, 2, true)
end

local function DestoryCamera()
    DestroyCam(createdCamera, false)
    RenderScriptCams(false, false, 1, true, true)
    SetFocusEntity(GetPlayerPed(ped))
    ClearPedTasksImmediately(ped)
    FreezeEntityPosition(ped, false)
    DeleteObject(overlay)
    DeleteObject(board)
    handle = nil
    createdCamera = 0
end

RegisterNetEvent('cqc-mugshot:client:trigger', function()
    ped = PlayerPedId()
    pedcoords = GetEntityCoords(ped)
    CreateThread(function()
        MugshotArray, mugshotInProgress = {}, true
        local citizenid = Framework.GetPlayerCitizenId()
        local animDict = 'mp_character_creation@lineup@male_a'
        while not HasAnimDictLoaded(animDict) do
            RequestAnimDict(animDict)
            Wait(100)
        end
        PrepBoard()
        Wait(250)
        MakeBoard()
        MugShotCamera()
        SetEntityCoords(ped, suspectx, suspecty, suspectz)
        SetEntityHeading(ped, suspectheading)
        PlayerBoard()
        TaskPlayAnim(ped, animDict, "loop_raised", 8.0, 8.0, -1, 49, 0, false, false, false)
        PhotoProcess(ped)
        if createdCamera ~= 0 then
            DestoryCamera()
            SetEntityHeading(ped, suspectheading)
            ClearPedSecondaryTask(GetPlayerPed(ped))
        end
        
        TriggerServerEvent('psmdt-mugshot:server:MDTupload', citizenid, MugshotArray)
        mugshotInProgress = false
    end)
end)

RegisterNUICallback("sendToJail", function(data, cb)
    local citizenId, sentence = data.citizenId, data.sentence

    -- Gets the player id from the citizenId
    local p = promise.new()
    Framework.TriggerServerCallback('mdt:server:GetPlayerSourceId', function(result)
        p:resolve(result)
    end, citizenId)

    local targetSourceId = Citizen.Await(p)

    if sentence > 0 then
        if Config.UseCQCMugshot    then
            TriggerServerEvent('cqc-mugshot:server:triggerSuspect', targetSourceId)
        end
        Citizen.Wait(5000)
        Framework.JailPlayer(targetSourceId, sentence)
    end
end)