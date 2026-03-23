local resourceName = tostring(GetCurrentResourceName())

-- Join a report editing session
RegisterNUICallback('joinReportSession', function(data, cb)
    if not data or not data.reportId then cb({ success = false }) return end
    local result = ps.callback(resourceName .. ':server:joinReportSession', data.reportId)
    cb(result or { success = false })
end)

-- Leave a report editing session
RegisterNUICallback('leaveReportSession', function(data, cb)
    if not data or not data.reportId then cb({ success = true }) return end
    local result = ps.callback(resourceName .. ':server:leaveReportSession', data.reportId)
    cb(result or { success = true })
end)

RegisterNUICallback('syncYjsUpdate', function(data, cb)
    cb({ success = true })
    if not data or not data.reportId or not data.update then return end
    TriggerServerEvent(resourceName .. ':server:collabSyncYjs', data.reportId, data.update)
end)

-- Sync structured data (suspects, charges, etc) - fire and forget
RegisterNUICallback('syncReportData', function(data, cb)
    cb({ success = true })
    if not data or not data.reportId or not data.dataType then return end
    TriggerServerEvent(resourceName .. ':server:collabSyncData', data.reportId, data.dataType, data.data)
end)

-- Server push events -> forward to NUI
RegisterNetEvent(resourceName .. ':client:reportEditorJoined')
AddEventHandler(resourceName .. ':client:reportEditorJoined', function(data)
    SendNUI('reportEditorJoined', data)
end)

RegisterNetEvent(resourceName .. ':client:reportEditorLeft')
AddEventHandler(resourceName .. ':client:reportEditorLeft', function(data)
    SendNUI('reportEditorLeft', data)
end)

local yjsIncomingBuffer = {}

RegisterNetEvent(resourceName .. ':client:yjsBatch')
AddEventHandler(resourceName .. ':client:yjsBatch', function(data)
    yjsIncomingBuffer[#yjsIncomingBuffer + 1] = data
end)

RegisterNetEvent(resourceName .. ':client:yjsUpdate')
AddEventHandler(resourceName .. ':client:yjsUpdate', function(data)
    yjsIncomingBuffer[#yjsIncomingBuffer + 1] = data
end)

RegisterNUICallback('pollYjsUpdates', function(data, cb)
    if #yjsIncomingBuffer == 0 then
        cb({ updates = {} })
        return
    end
    local batch = yjsIncomingBuffer
    yjsIncomingBuffer = {}
    cb({ updates = batch })
end)

-- Structured data update from server
RegisterNetEvent(resourceName .. ':client:reportDataUpdate')
AddEventHandler(resourceName .. ':client:reportDataUpdate', function(data)
    SendNUI('reportDataUpdate', data)
end)
