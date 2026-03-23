local resourceName = tostring(GetCurrentResourceName())

-- In-memory state for active report editing sessions
local activeReportSessions = {}

-- Color palette for editor cursors/presence
local EDITOR_COLORS = { '#3B82F6', '#EF4444', '#10B981', '#F59E0B', '#8B5CF6', '#EC4899', '#06B6D4', '#F97316' }

local function getNextColor(session)
    local usedColors = {}
    for _, editor in pairs(session.editors) do
        usedColors[editor.color] = true
    end
    for _, color in ipairs(EDITOR_COLORS) do
        if not usedColors[color] then return color end
    end
    return EDITOR_COLORS[1]
end

local function getEditorsList(session, excludeSource)
    local list = {}
    for src, editor in pairs(session.editors) do
        if src ~= excludeSource then
            list[#list + 1] = {
                source = src,
                name = editor.name,
                citizenid = editor.citizenid,
                color = editor.color,
            }
        end
    end
    return list
end

local function broadcastToEditors(reportId, eventName, data, excludeSource)
    local session = activeReportSessions[reportId]
    if not session then return end
    for src, _ in pairs(session.editors) do
        if src ~= excludeSource then
            TriggerClientEvent(resourceName .. ':client:' .. eventName, src, data)
        end
    end
end

-- Cleanup stale sessions (30 min timeout)
CreateThread(function()
    while true do
        Wait(60000)
        local now = os.time()
        for reportId, session in pairs(activeReportSessions) do
            local hasEditors = false
            for src, editor in pairs(session.editors) do
                if (now - editor.lastActivity) > 1800 then
                    session.editors[src] = nil
                    broadcastToEditors(reportId, 'reportEditorLeft', {
                        reportId = reportId,
                        source = src,
                        editors = getEditorsList(session)
                    })
                else
                    hasEditors = true
                end
            end
            if not hasEditors then
                activeReportSessions[reportId] = nil
            end
        end
    end
end)

-- Join a report editing session
ps.registerCallback(resourceName .. ':server:joinReportSession', function(source, reportId)
    local src = source
    if not CheckAuth(src) then return { success = false } end

    reportId = tostring(reportId)
    if not reportId or reportId == '' then return { success = false } end

    -- Create session if it doesn't exist
    if not activeReportSessions[reportId] then
        activeReportSessions[reportId] = {
            editors = {},
            yjsState = nil,
            lastStructuredData = {},
        }
    end

    local session = activeReportSessions[reportId]
    local citizenId = ps.getIdentifier(src)
    local profile = MySQL.single.await('SELECT fullname FROM mdt_profiles WHERE citizenid = ?', { citizenId })
    local editorName = profile and profile.fullname or 'Unknown'
    local color = getNextColor(session)

    -- Register editor
    session.editors[src] = {
        name = editorName,
        citizenid = citizenId,
        color = color,
        joinedAt = os.time(),
        lastActivity = os.time(),
    }

    -- Notify other editors
    broadcastToEditors(reportId, 'reportEditorJoined', {
        reportId = reportId,
        editor = {
            source = src,
            name = editorName,
            citizenid = citizenId,
            color = color,
        },
        editors = getEditorsList(session)
    }, src)

    -- Return current state to the joining editor
    return {
        success = true,
        color = color,
        myName = editorName,
        myCitizenId = citizenId,
        editors = getEditorsList(session, src),
        yjsState = session.yjsState,
        lastStructuredData = session.lastStructuredData,
    }
end)

-- Leave a report editing session
ps.registerCallback(resourceName .. ':server:leaveReportSession', function(source, reportId)
    local src = source
    reportId = tostring(reportId)

    local session = activeReportSessions[reportId]
    if not session then return { success = true } end

    session.editors[src] = nil

    -- Notify others
    broadcastToEditors(reportId, 'reportEditorLeft', {
        reportId = reportId,
        source = src,
        editors = getEditorsList(session)
    })

    -- Cleanup empty sessions
    local hasEditors = false
    for _ in pairs(session.editors) do hasEditors = true break end
    if not hasEditors then
        activeReportSessions[reportId] = nil
    end

    return { success = true }
end)

local yjsPendingBroadcasts = {}

RegisterNetEvent(resourceName .. ':server:collabSyncYjs')
AddEventHandler(resourceName .. ':server:collabSyncYjs', function(reportId, update)
    local src = source
    if not CheckAuth(src) then return end

    reportId = tostring(reportId)
    local session = activeReportSessions[reportId]
    if not session or not session.editors[src] then return end

    session.editors[src].lastActivity = os.time()

    -- Store for late joiners
    if not session.yjsUpdates then session.yjsUpdates = {} end
    session.yjsUpdates[#session.yjsUpdates + 1] = update
    session.yjsState = update
    if #session.yjsUpdates > 100 then
        session.yjsState = update
        session.yjsUpdates = { update }
    end

    -- Queue for batched broadcast
    if not yjsPendingBroadcasts[reportId] then
        yjsPendingBroadcasts[reportId] = { updates = {}, sources = {} }
    end
    local pending = yjsPendingBroadcasts[reportId]
    pending.updates[#pending.updates + 1] = update
    pending.sources[src] = true

    -- Schedule flush if not already scheduled
    if not pending.timer then
        pending.timer = true
        SetTimeout(250, function()
            local batch = yjsPendingBroadcasts[reportId]
            yjsPendingBroadcasts[reportId] = nil
            if not batch or #batch.updates == 0 then return end

            local currentSession = activeReportSessions[reportId]
            if not currentSession then return end

            -- Send single batched event to each editor (excluding senders)
            for editorSrc, _ in pairs(currentSession.editors) do
                if not batch.sources[editorSrc] then
                    TriggerClientEvent(resourceName .. ':client:yjsBatch', editorSrc, {
                        reportId = reportId,
                        updates = batch.updates,
                    })
                end
            end
        end)
    end
end)

RegisterNetEvent(resourceName .. ':server:collabSyncData')
AddEventHandler(resourceName .. ':server:collabSyncData', function(reportId, dataType, data)
    local src = source
    if not CheckAuth(src) then return end

    reportId = tostring(reportId)
    local session = activeReportSessions[reportId]
    if not session or not session.editors[src] then return end

    session.lastStructuredData[dataType] = data
    session.editors[src].lastActivity = os.time()

    broadcastToEditors(reportId, 'reportDataUpdate', {
        reportId = reportId,
        dataType = dataType,
        data = data,
        source = src,
    }, src)
end)

-- Cleanup on player disconnect
AddEventHandler('playerDropped', function()
    local src = source
    for reportId, session in pairs(activeReportSessions) do
        if session.editors[src] then
            session.editors[src] = nil
            broadcastToEditors(reportId, 'reportEditorLeft', {
                reportId = reportId,
                source = src,
                editors = getEditorsList(session)
            })
            local hasEditors = false
            for _ in pairs(session.editors) do hasEditors = true break end
            if not hasEditors then
                activeReportSessions[reportId] = nil
            end
        end
    end
end)
