QBCore = exports['qb-core']:GetCoreObject()
local PlayerData = {}
local CurrentCops = 0
local isOpen = false
local callSign = ""
local tablet = 0
local tabletDict = "amb@code_human_in_bus_passenger_idles@female@tablet@base"
local tabletAnim = "base"
local tabletProp = `prop_cs_tablet`
local tabletBone = 60309
local tabletOffset = vector3(0.03, 0.002, -0.0)
local tabletRot = vector3(10.0, 160.0, 0.0)

-- Events from qbcore
RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    PlayerData = QBCore.Functions.GetPlayerData()
    callSign = PlayerData.metadata.callsign
end)

RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    TriggerServerEvent("ps-mdt:server:OnPlayerUnload")
    PlayerData = {}
end)

RegisterNetEvent('QBCore:Client:OnJobUpdate', function(JobInfo)
    PlayerData.job = JobInfo
end)

RegisterNetEvent('QBCore:Client:OnGangUpdate', function(GangInfo)
    PlayerData.gang = GangInfo
end)

RegisterNetEvent("QBCore:Client:SetDuty", function(job, state)
    if AllowedJob(job) then
        TriggerServerEvent("ps-mdt:server:ToggleDuty")
    end
end)

RegisterNetEvent('police:SetCopCount', function(amount)
    CurrentCops = amount
end)

RegisterNetEvent('QBCore:Player:SetPlayerData', function(val)
    PlayerData = val
end)

AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    Wait(150)
    PlayerData = QBCore.Functions.GetPlayerData()
    callSign = PlayerData.metadata.callsign
end)

--====================================================================================
------------------------------------------
--                Functions             --
------------------------------------------
--====================================================================================\

RegisterKeyMapping('mdt', 'Open Police MDT', 'keyboard', 'k')

RegisterCommand('mdt', function()
    local plyPed = PlayerPedId()
    PlayerData = QBCore.Functions.GetPlayerData()
    if not PlayerData.metadata["isdead"] and not PlayerData.metadata["inlaststand"] and not PlayerData.metadata["ishandcuffed"] and not IsPauseMenuActive() then
        if GetJobType(PlayerData.job.name) ~= nil then
            TriggerServerEvent('mdt:server:openMDT')
        end
    else
        QBCore.Functions.Notify("Can't do that!", "error")
    end
end, false)

Citizen.CreateThread(function()
    TriggerEvent('chat:addSuggestion', '/mdt', 'Open the emergency services MDT', {})
end)

local function doAnimation()
    if not isOpen then return end
    -- Animation
    RequestAnimDict(tabletDict)
    while not HasAnimDictLoaded(tabletDict) do Citizen.Wait(100) end
    -- Model
    RequestModel(tabletProp)
    while not HasModelLoaded(tabletProp) do Citizen.Wait(100) end

    local plyPed = PlayerPedId()
    local tabletObj = CreateObject(tabletProp, 0.0, 0.0, 0.0, true, true, false)
    local tabletBoneIndex = GetPedBoneIndex(plyPed, tabletBone)

    AttachEntityToEntity(tabletObj, plyPed, tabletBoneIndex, tabletOffset.x, tabletOffset.y, tabletOffset.z, tabletRot.x, tabletRot.y, tabletRot.z, true, false, false, false, 2, true)
    SetModelAsNoLongerNeeded(tabletProp)

    CreateThread(function()
        while isOpen do
            Wait(0)
            if not IsEntityPlayingAnim(plyPed, tabletDict, tabletAnim, 3) then
                TaskPlayAnim(plyPed, tabletDict, tabletAnim, 3.0, 3.0, -1, 49, 0, 0, 0, 0)
            end
        end


        ClearPedSecondaryTask(plyPed)
        Citizen.Wait(250)
        DetachEntity(tabletObj, true, false)
        DeleteEntity(tabletObj)
    end)
end


local function CurrentDuty(duty)
    if duty == 1 then
        return "10-41"
    end
    return "10-42"
end

local function EnableGUI(enable)
    SetNuiFocus(enable, enable)
    SendNUIMessage({ type = "show", enable = enable, job = PlayerData.job.name, rosterLink = Config.RosterLink[PlayerData.job.name] })
    isOpen = enable
    doAnimation()
end

local function RefreshGUI()
    SetNuiFocus(false, false)
    SendNUIMessage({ type = "show", enable = false, job = PlayerData.job.name, rosterLink = Config.RosterLink[PlayerData.job.name] })
    isOpen = false
end

--// Non local function so above EHs can utilise
function AllowedJob(job)
    for key, _ in pairs(Config.AllowedJobs) do
        if key == job then
            return true
        end
    end
    --// Return false if current job is not in allowed list
    return false
end


--====================================================================================
------------------------------------------
--               MAIN PAGE              --
------------------------------------------
--====================================================================================


RegisterCommand("restartmdt", function(source, args, rawCommand)
	RefreshGUI()
end, false)

RegisterNUICallback("deleteBulletin", function(data, cb)
    local id = data.id
    TriggerServerEvent('mdt:server:deleteBulletin', id, data.title)
    cb(true)
end)

RegisterNUICallback("newBulletin", function(data, cb)
    local title = data.title
    local info = data.info
    local time = data.time
    TriggerServerEvent('mdt:server:NewBulletin', title, info, time)
    cb(true)
end)

RegisterNUICallback('escape', function(data, cb)
    EnableGUI(false)
    cb(true)
end)

RegisterNetEvent('mdt:client:dashboardbulletin', function(sentData)
    SendNUIMessage({ type = "bulletin", data = sentData })
end)

RegisterNetEvent('mdt:client:dashboardWarrants', function()
    QBCore.Functions.TriggerCallback("mdt:server:getWarrants", function(data)
        if data then
            SendNUIMessage({ type = "warrants", data = data })
        end
    end)
    -- SendNUIMessage({ type = "warrants",})
end)

RegisterNUICallback("getAllDashboardData", function(data, cb)
    TriggerEvent("mdt:client:dashboardWarrants")
    cb(true)
end)


RegisterNetEvent('mdt:client:dashboardReports', function(sentData)
    SendNUIMessage({ type = "reports", data = sentData })
end)

RegisterNetEvent('mdt:client:dashboardCalls', function(sentData)
    SendNUIMessage({ type = "calls", data = sentData })
end)

RegisterNetEvent('mdt:client:newBulletin', function(ignoreId, sentData, job)
    if ignoreId == GetPlayerServerId(PlayerId()) then return end;
    if AllowedJob(PlayerData.job.name) then
        SendNUIMessage({ type = "newBulletin", data = sentData })
    end
end)

RegisterNetEvent('mdt:client:deleteBulletin', function(ignoreId, sentData, job)
    if ignoreId == GetPlayerServerId(PlayerId()) then return end;
    if AllowedJob(PlayerData.job.name) then
        SendNUIMessage({ type = "deleteBulletin", data = sentData })
    end
end)

RegisterNetEvent('mdt:client:open', function(bulletin, activeUnits, calls, cid)
    EnableGUI(true)
    local x, y, z = table.unpack(GetEntityCoords(PlayerPedId()))

    local currentStreetHash, intersectStreetHash = GetStreetNameAtCoord(x, y, z)
    local currentStreetName = GetStreetNameFromHashKey(currentStreetHash)
    local intersectStreetName = GetStreetNameFromHashKey(intersectStreetHash)
    local zone = tostring(GetNameOfZone(x, y, z))
    local area = GetLabelText(zone)
    local playerStreetsLocation = area

    if not zone then zone = "UNKNOWN" end;

    if intersectStreetName ~= nil and intersectStreetName ~= "" then playerStreetsLocation = currentStreetName .. ", " .. intersectStreetName .. ", " .. area
    elseif currentStreetName ~= nil and currentStreetName ~= "" then playerStreetsLocation = currentStreetName .. ", " .. area
    else playerStreetsLocation = area end

    -- local grade = PlayerData.job.grade.name

    SendNUIMessage({ type = "data", activeUnits = activeUnits, citizenid = cid, ondutyonly = Config.OnlyShowOnDuty, name = "Welcome, " ..PlayerData.job.grade.name..' '..PlayerData.charinfo.lastname:sub(1,1):upper()..PlayerData.charinfo.lastname:sub(2), location = playerStreetsLocation, fullname = PlayerData.charinfo.firstname..' '..PlayerData.charinfo.lastname, bulletin = bulletin })
    SendNUIMessage({ type = "calls", data = calls })
    TriggerEvent("mdt:client:dashboardWarrants")
end)

RegisterNetEvent('mdt:client:exitMDT', function()
    EnableGUI(false)
end)

--====================================================================================
------------------------------------------
--             PROFILE PAGE             --
------------------------------------------
--====================================================================================

RegisterNUICallback("searchProfiles", function(data, cb)
    local p = promise.new()

    QBCore.Functions.TriggerCallback('mdt:server:SearchProfile', function(result)
        p:resolve(result)
    end, data.name)

    local data = Citizen.Await(p)

    cb(data)
end)


RegisterNetEvent('mdt:client:searchProfile', function(sentData, isLimited)
    SendNUIMessage({ type = "profiles", data = sentData, isLimited = isLimited })
end)

RegisterNUICallback("saveProfile", function(data, cb)
    local profilepic = data.pfp
    local information = data.description
    local cid = data.id
    local fName = data.fName
    local sName = data.sName
    local tags = data.tags
    local gallery = data.gallery
    local fingerprint = data.fingerprint
    local licenses = data.licenses

    TriggerServerEvent("mdt:server:saveProfile", profilepic, information, cid, fName, sName, tags, gallery, fingerprint, licenses)
    cb(true)
end)

RegisterNUICallback("getProfileData", function(data, cb)
    local id = data.id
    local p = nil
    local getProfileDataPromise = function(data)
        if p then return end
        p = promise.new()
        QBCore.Functions.TriggerCallback('mdt:server:GetProfileData', function(result)
            p:resolve(result)
        end, data)
        return Citizen.Await(p)
    end
    local pP = nil
    local result = getProfileDataPromise(id)

    --[[ local getProfileProperties = function(data)
        if pP then return end
        pP = promise.new()
        QBCore.Functions.TriggerCallback('qb-phone:server:MeosGetPlayerHouses', function(result)
            pP:resolve(result)
        end, data)
        return Citizen.Await(pP)
    end
    local propertiesResult = getProfileProperties(id)
    result.properties = propertiesResult
     ]]
    local vehicles=result.vehicles
    for i=1,#vehicles do
        local vehicle=result.vehicles[i]
        result.vehicles[i]['model'] = GetLabelText(GetDisplayNameFromVehicleModel(vehicle['vehicle']))
    end
    p = nil
    return cb(result)
end)

RegisterNUICallback("newTag", function(data, cb)
    if data.id ~= "" and data.tag ~= "" then
        TriggerServerEvent('mdt:server:newTag', data.id, data.tag)
    end
    cb(true)
end)

RegisterNUICallback("removeProfileTag", function(data, cb)
    local cid = data.cid
    local tagtext = data.text
    TriggerServerEvent('mdt:server:removeProfileTag', cid, tagtext)
    cb(true)
end)

RegisterNUICallback("updateLicence", function(data, cb)
    local type = data.type
    local status = data.status
    local cid = data.cid
    TriggerServerEvent('mdt:server:updateLicense', cid, type, status)
    cb(true)
end)

RegisterNUICallback("searchIncidents", function(data, cb)
    local incident = data.incident
    TriggerServerEvent('mdt:server:searchIncidents', incident)
    cb(true)
end)

RegisterNUICallback("getIncidentData", function(data, cb)
    local id = data.id
    TriggerServerEvent('mdt:server:getIncidentData', id)
    cb(true)
end)

RegisterNUICallback("incidentSearchPerson", function(data, cb)
    local name = data.name
    TriggerServerEvent('mdt:server:incidentSearchPerson', name )
    cb(true)
end)

RegisterNetEvent('mdt:client:getProfileData', function(sentData, isLimited)
    if not isLimited then
        local vehicles = sentData['vehicles']
        for i=1, #vehicles do
            sentData['vehicles'][i]['plate'] = string.upper(sentData['vehicles'][i]['plate'])
            local tempModel = vehicles[i]['model']
            if tempModel and tempModel ~= "Unknown" then
                local DisplayNameModel = GetDisplayNameFromVehicleModel(tempModel)
                local LabelText = GetLabelText(DisplayNameModel)
                if LabelText == "NULL" then LabelText = DisplayNameModel end
                sentData['vehicles'][i]['model'] = LabelText
            end
        end
    end
    SendNUIMessage({ type = "profileData", data = sentData, isLimited = isLimited })
end)

RegisterNetEvent('mdt:client:getIncidents', function(sentData)
    SendNUIMessage({ type = "incidents", data = sentData })
end)

RegisterNetEvent('mdt:client:getIncidentData', function(sentData, sentConvictions)
    SendNUIMessage({ type = "incidentData", data = sentData, convictions = sentConvictions })
end)

RegisterNetEvent('mdt:client:incidentSearchPerson', function(sentData)
    SendNUIMessage({ type = "incidentSearchPerson", data = sentData })
end)


RegisterNUICallback('SetHouseLocation', function(data, cb)
    local coords = {}
    for word in data.coord[1]:gmatch('[^,%s]+') do
        coords[#coords+1] = tonumber(word)
    end
    SetNewWaypoint(coords[1], coords[2])
    QBCore.Functions.Notify('GPS has been set!', 'success')
end)

--====================================================================================
------------------------------------------
--               BOLO PAGE              --
------------------------------------------
--====================================================================================

RegisterNUICallback("searchBolos", function(data, cb)
    local searchVal = data.searchVal
    TriggerServerEvent('mdt:server:searchBolos', searchVal)
    cb(true)
end)

RegisterNUICallback("getAllBolos", function(data, cb)
    TriggerServerEvent('mdt:server:getAllBolos')
    cb(true)
end)

RegisterNUICallback("getAllIncidents", function(data, cb)
    TriggerServerEvent('mdt:server:getAllIncidents')
    cb(true)
end)

RegisterNUICallback("getBoloData", function(data, cb)
    local id = data.id
    TriggerServerEvent('mdt:server:getBoloData', id)
    cb(true)
end)

RegisterNUICallback("newBolo", function(data, cb)
    local existing = data.existing
    local id = data.id
    local title = data.title
    local plate = data.plate
    local owner = data.owner
    local individual = data.individual
    local detail = data.detail
    local tags = data.tags
    local gallery = data.gallery
    local officers = data.officers
    local time = data.time
    TriggerServerEvent('mdt:server:newBolo', existing, id, title, plate, owner, individual, detail, tags, gallery, officers, time)
    cb(true)
end)

RegisterNUICallback("deleteBolo", function(data, cb)
    local id = data.id
    TriggerServerEvent('mdt:server:deleteBolo', id)
    cb(true)
end)

RegisterNUICallback("deleteICU", function(data, cb)
    local id = data.id
    TriggerServerEvent('mdt:server:deleteICU', id)
    cb(true)
end)

RegisterNetEvent('mdt:client:getBolos', function(sentData)
    SendNUIMessage({ type = "bolos", data = sentData })
end)

RegisterNetEvent('mdt:client:getAllIncidents', function(sentData)
    SendNUIMessage({ type = "incidents", data = sentData })
end)

RegisterNetEvent('mdt:client:getAllBolos', function(sentData)
    SendNUIMessage({ type = "bolos", data = sentData })
end)

RegisterNetEvent('mdt:client:getBoloData', function(sentData)
    SendNUIMessage({ type = "boloData", data = sentData })
end)

RegisterNetEvent('mdt:client:boloComplete', function(sentData)
    SendNUIMessage({ type = "boloComplete", data = sentData })
end)

--====================================================================================
------------------------------------------
--               REPORTS PAGE           --
------------------------------------------
--====================================================================================

RegisterNUICallback("getAllReports", function(data, cb)
    TriggerServerEvent('mdt:server:getAllReports')
    cb(true)
end)

RegisterNUICallback("getReportData", function(data, cb)
    local id = data.id
    TriggerServerEvent('mdt:server:getReportData', id)
    cb(true)
end)

RegisterNUICallback("searchReports", function(data, cb)
    local name = data.name
    TriggerServerEvent('mdt:server:searchReports', name)
    cb(true)
end)

RegisterNUICallback("newReport", function(data, cb)
    local existing = data.existing
    local id = data.id
    local title = data.title
    local reporttype = data.type
    local details = data.details
    local tags = data.tags
    local gallery = data.gallery
    local officers = data.officers
    local civilians = data.civilians
    local time = data.time

    TriggerServerEvent('mdt:server:newReport', existing, id, title, reporttype, details, tags, gallery, officers, civilians, time)
    cb(true)
end)

RegisterNetEvent('mdt:client:getAllReports', function(sentData)
    SendNUIMessage({ type = "reports", data = sentData })
end)

RegisterNetEvent('mdt:client:getReportData', function(sentData)
    SendNUIMessage({ type = "reportData", data = sentData })
end)

RegisterNetEvent('mdt:client:reportComplete', function(sentData)
    SendNUIMessage({ type = "reportComplete", data = sentData })
end)

--====================================================================================
------------------------------------------
--                DMV PAGE              --
------------------------------------------
--====================================================================================
RegisterNUICallback("searchVehicles", function(data, cb)

    local p = promise.new()

    QBCore.Functions.TriggerCallback('mdt:server:SearchVehicles', function(result)
        p:resolve(result)
    end, data.name)

    local result = Citizen.Await(p)
    for i=1, #result do
        local vehicle = result[i]
        local mods = json.decode(result[i].mods)
        result[i]['plate'] = string.upper(result[i]['plate'])
        result[i]['color'] = Config.ColorInformation[mods['color1']]
        result[i]['colorName'] = Config.ColorNames[mods['color1']]
        result[i]['model'] = GetLabelText(GetDisplayNameFromVehicleModel(vehicle['vehicle']))
    end
    cb(result)

end)

RegisterNUICallback("getVehicleData", function(data, cb)
    local plate = data.plate
    TriggerServerEvent('mdt:server:getVehicleData', plate)
    cb(true)
end)

RegisterNUICallback("saveVehicleInfo", function(data, cb)
    local dbid = data.dbid
    local plate = data.plate
    local imageurl = data.imageurl
    local notes = data.notes
    local stolen = data.stolen
    local code5 = data.code5
    local impound = data.impound
    local JobType = GetJobType(PlayerData.job.name)
    if JobType == 'police' and impound.impoundChanged == true then
        if impound.impoundActive then
            local found = 0
            local plate = string.upper(string.gsub(data['plate'], "^%s*(.-)%s*$", "%1"))
            local vehicles = GetGamePool('CVehicle')

            for k,v in pairs(vehicles) do
                local plt = string.upper(string.gsub(GetVehicleNumberPlateText(v), "^%s*(.-)%s*$", "%1"))
                if plt == plate then
                    local dist = #(GetEntityCoords(PlayerPedId()) - GetEntityCoords(v))
                    if dist < 5.0 then
                        found = VehToNet(v)
                        SendNUIMessage({ type = "greenImpound" })
                        TriggerServerEvent('mdt:server:saveVehicleInfo', dbid, plate, imageurl, notes, stolen, code5, impound)
                    end
                    break
                end
            end

            if found == 0 then
                QBCore.Functions.Notify('Vehicle not found!', 'error')
                SendNUIMessage({ type = "redImpound" })
            end
        else
            local ped = PlayerPedId()
            local playerPos = GetEntityCoords(ped)
            for k, v in pairs(Config.ImpoundLocations) do
                if (#(playerPos - vector3(v.x, v.y, v.z)) < 20.0) then
                    impound.CurrentSelection = k
                    TriggerServerEvent('mdt:server:saveVehicleInfo', dbid, plate, imageurl, notes, stolen, code5, impound)
                    break
                end
            end
        end
    else
        TriggerServerEvent('mdt:server:saveVehicleInfo', dbid, plate, imageurl, notes, stolen, code5, impound)
    end
    cb(true)
end)

RegisterNUICallback("getAllLogs", function(data, cb)
    TriggerServerEvent('mdt:server:getAllLogs')
    cb(true)
end)

RegisterNUICallback("getPenalCode", function(data, cb)
    TriggerServerEvent('mdt:server:getPenalCode')
    cb(true)
end)

RegisterNUICallback("toggleDuty", function(data, cb)
    TriggerServerEvent('QBCore:ToggleDuty')
    cb(true)
end)

RegisterNUICallback("setCallsign", function(data, cb)
    TriggerServerEvent('mdt:server:setCallsign', data.cid, data.newcallsign)
    cb(true)
end)

RegisterNUICallback("setRadio", function(data, cb)
    TriggerServerEvent('mdt:server:setRadio', data.cid, data.newradio)
    cb(true)
end)

RegisterNUICallback("saveIncident", function(data, cb)
    TriggerServerEvent('mdt:server:saveIncident', data.ID, data.title, data.information, data.tags, data.officers, data.civilians, data.evidence, data.associated, data.time)
    cb(true)
end)

RegisterNUICallback("removeIncidentCriminal", function(data, cb)
    TriggerServerEvent('mdt:server:removeIncidentCriminal', data.cid, data.incidentId)
    cb(true)
end)

RegisterNetEvent('mdt:client:getVehicleData', function(sentData)
    if sentData and sentData[1] then
        local vehicle = sentData[1]
        local vehData = json.decode(vehicle['vehicle'])
        vehicle['color'] = Config.ColorInformation[vehicle['color1']]
        vehicle['colorName'] = Config.ColorNames[vehicle['color1']]
        vehicle['model'] = GetLabelText(GetDisplayNameFromVehicleModel(vehicle['vehicle']))
        vehicle['class'] = Config.ClassList[GetVehicleClassFromName(vehicle['vehicle'])]
        vehicle['vehicle'] = nil
        SendNUIMessage({ type = "getVehicleData", data = vehicle })
    end
end)

RegisterNetEvent('mdt:client:updateVehicleDbId', function(sentData)
    SendNUIMessage({ type = "updateVehicleDbId", data = tonumber(sentData) })
end)

RegisterNetEvent('mdt:client:getAllLogs', function(sentData)
    SendNUIMessage({ type = "getAllLogs", data = sentData })
end)

RegisterNetEvent('mdt:client:getPenalCode', function(titles, penalcode)
    SendNUIMessage({ type = "getPenalCode", titles = titles, penalcode = penalcode })
end)

RegisterNetEvent('mdt:client:setRadio', function(radio)
    if type(tonumber(radio)) == "number" then
        exports["pma-voice"]:setVoiceProperty("radioEnabled", true)
        exports["pma-voice"]:setRadioChannel(tonumber(radio))
        QBCore.Functions.Notify("You have set your radio frequency to "..radio..".", "success")
    else
        QBCore.Functions.Notify("Invalid Station(Please enter a number)", "error")
    end
end)

RegisterNetEvent('mdt:client:sig100', function(radio, type)
    local job = PlayerData.job.name
    local duty = PlayerData.job.onduty
    if AllowedJob(job) and duty == 1 then
        if type == true then
            exports['erp_notifications']:PersistentAlert("START", "signall100-"..radio, "inform", "Radio "..radio.." is currently signal 100!")
        end
    end
    if not type then
        exports['erp_notifications']:PersistentAlert("END", "signall100-"..radio)
    end
end)

RegisterNetEvent('mdt:client:updateCallsign', function(callsign)
    callSign = tostring(callsign)
end)

RegisterNetEvent('mdt:client:updateIncidentDbId', function(sentData)
    SendNUIMessage({ type = "updateIncidentDbId", data = tonumber(sentData) })
end)


--====================================================================================
------------------------------------------
--               DISPATCH PAGE          --
------------------------------------------
--====================================================================================

RegisterNetEvent('dispatch:clNotify', function(sNotificationData, sNotificationId)
    if LocalPlayer.state.isLoggedIn then
        sNotificationData.playerJob = PlayerData.job.name
        SendNUIMessage({ type = "call", data = sNotificationData })
    end
end)

RegisterNUICallback("setWaypoint", function(data, cb)
    TriggerServerEvent('mdt:server:setWaypoint', data.callid)
    cb(true)
end)

RegisterNUICallback("callDetach", function(data, cb)
    TriggerServerEvent('mdt:server:callDetach', data.callid)
    cb(true)
end)

RegisterNUICallback("removeCallBlip", function(data, cb)
    TriggerEvent('ps-dispatch:client:removeCallBlip', data.callid)
    cb(true)
end)

RegisterNUICallback("callAttach", function(data, cb)
    TriggerServerEvent('mdt:server:callAttach', data.callid)
    cb(true)
end)

RegisterNUICallback("attachedUnits", function(data, cb)
    TriggerServerEvent('mdt:server:attachedUnits', data.callid)
    cb(true)
end)

RegisterNUICallback("callDispatchDetach", function(data, cb)
    TriggerServerEvent('mdt:server:callDispatchDetach', data.callid, data.cid)
    cb(true)
end)

RegisterNUICallback("setDispatchWaypoint", function(data, cb)
    TriggerServerEvent('mdt:server:setDispatchWaypoint', data.callid, data.cid)
    cb(true)
end)

RegisterNUICallback("callDragAttach", function(data, cb)
    TriggerServerEvent('mdt:server:callDragAttach', data.callid, data.cid)
    cb(true)
end)

RegisterNUICallback("setWaypointU", function(data, cb)
    TriggerServerEvent('mdt:server:setWaypoint:unit', data.cid)
    cb(true)
end)

RegisterNUICallback("dispatchMessage", function(data, cb)
    TriggerServerEvent('mdt:server:sendMessage', data.message, data.time)
    cb(true)
end)

RegisterNUICallback("refreshDispatchMsgs", function(data, cb)
    TriggerServerEvent('mdt:server:refreshDispatchMsgs')
    cb(true)
end)

RegisterNUICallback("dispatchNotif", function(data, cb)
    local info = data['data']
    local mentioned = false
    if callSign ~= "" then if string.find(string.lower(info['message']),string.lower(string.gsub(callSign,'-','%%-'))) then mentioned = true end end
    if mentioned then

        -- Send notification to phone??
        TriggerEvent('erp_phone:sendNotification', {img = info['profilepic'], title = "Dispatch (Mention)", content = info['message'], time = 7500, customPic = true })

        PlaySoundFrontend(-1, "SELECT", "HUD_FRONTEND_DEFAULT_SOUNDSET", false)
        PlaySoundFrontend(-1, "Event_Start_Text", "GTAO_FM_Events_Soundset", 0)
    else
        TriggerEvent('erp_phone:sendNotification', {img = info['profilepic'], title = "Dispatch ("..info['name']..")", content = info['message'], time = 5000, customPic = true })
    end
    cb(true)
end)

RegisterNUICallback("getCallResponses", function(data, cb)
    TriggerServerEvent('mdt:server:getCallResponses', data.callid)
    cb(true)
end)

RegisterNUICallback("sendCallResponse", function(data, cb)
    TriggerServerEvent('mdt:server:sendCallResponse', data.message, data.time, data.callid)
    cb(true)
end)

--[[ RegisterNUICallback("impoundVehicle", function(data, cb)
    local JobType = GetJobType(PlayerData.job.name)
    if JobType == 'police' then
        local found = 0
        local plate = string.upper(string.gsub(data['plate'], "^%s*(.-)%s*$", "%1"))
        local vehicles = GetGamePool('CVehicle')

        for k,v in pairs(vehicles) do
            local plt = string.upper(string.gsub(GetVehicleNumberPlateText(v), "^%s*(.-)%s*$", "%1"))
            if plt == plate then
                local dist = #(GetEntityCoords(PlayerPedId()) - GetEntityCoords(v))
                if dist < 5.0 then
                    found = VehToNet(v)
                end
                break
            end
        end

        if found == 0 then
            QBCore.Functions.Notify('Vehicle not found!', 'error')
            return
        end

        SendNUIMessage({ type = "greenShit" })
        TriggerServerEvent('mdt:server:impoundVehicle', data, found)
        cb('ok')
    end
end) ]]

RegisterNUICallback("removeImpound", function(data, cb)
    local ped = PlayerPedId()
    local playerPos = GetEntityCoords(ped)
    for k, v in pairs(Config.ImpoundLocations) do
        if (#(playerPos - vector3(v.x, v.y, v.z)) < 20.0) then
            TriggerServerEvent('mdt:server:removeImpound', data['plate'], k)
            break
        end
    end
	cb('ok')
end)

RegisterNUICallback("statusImpound", function(data, cb)
	TriggerServerEvent('mdt:server:statusImpound', data['plate'])
	cb('ok')
end)

RegisterNUICallback('openCamera', function(data)
    local camId = tonumber(data.cam)
    TriggerEvent('police:client:ActiveCamera', camId)
end)

RegisterNetEvent('mdt:client:attachedUnits', function(sentData, callid)
    SendNUIMessage({ type = "attachedUnits", data = sentData, callid = callid })
end)

RegisterNetEvent('mdt:client:setWaypoint', function(callInformation)
    SetNewWaypoint(callInformation['origin']['x'], callInformation['origin']['y'])
end)

RegisterNetEvent('mdt:client:callDetach', function(callid, sentData)
    local job = PlayerData.job.name
    if AllowedJob(job) then 
        SendNUIMessage({ type = "callDetach", callid = callid, data = tonumber(sentData) }) 
    end
end)
RegisterNetEvent('mdt:client:callAttach', function(callid, sentData)
    local job = PlayerData.job.name
    if AllowedJob(job) then 
        SendNUIMessage({ type = "callAttach", callid = callid, data = tonumber(sentData) })
    end
end)

RegisterNetEvent('mdt:client:setWaypoint:unit', function(sentData)
    SetNewWaypoint(sentData.x, sentData.y)
end)

RegisterNetEvent('mdt:client:dashboardMessage', function(sentData)
    local job = PlayerData.job.name
    if AllowedJob(job) then 
        SendNUIMessage({ type = "dispatchmessage", data = sentData })
    end
end)

RegisterNetEvent('mdt:client:dashboardMessages', function(sentData)
    SendNUIMessage({ type = "dispatchmessages", data = sentData })
end)

RegisterNetEvent('mdt:client:getCallResponses', function(sentData, sentCallId)
    SendNUIMessage({ type = "getCallResponses", data = sentData, callid = sentCallId })
end)

RegisterNetEvent('mdt:client:sendCallResponse', function(message, time, callid, name)
    SendNUIMessage({ type = "sendCallResponse", message = message, time = time, callid = callid, name = name })
end)

RegisterNetEvent('mdt:client:notifyMechanics', function(sentData)
    --[[if exports["erp-jobsystem"]:CanTow() then
        TriggerServerEvent('erp-sounds:PlayWithinDistance', 1.5, 'beep', 0.4)
        TriggerEvent('erp_phone:sendNotification', {img = 'vehiclenotif.png', title = "Impound", content = "New vehicle is ready to be impounded!", time = 5000 })
    end]]
end)

RegisterNetEvent('mdt:client:statusImpound', function(data, plate)
    SendNUIMessage({ type = "statusImpound", data = data, plate = plate })
end)
