local _SendNUIMessage = SendNUIMessage

-- Minimal, guaranteed-serialisable fallback used only if the real payload
-- can't be sent (non-encodable data). Plain data tables never hit this path.
local function safeFallback(action, data)
    if action == 'updateAuth' and type(data) == 'table' then
        local playerData = data.playerData
        return {
            authorized = data.authorized == true,
            isLEO = data.isLEO == true,
            onDuty = data.onDuty == true,
            jobType = data.jobType or 'leo',
            playerData = type(playerData) == 'table' and {
                citizenid = playerData.citizenid,
                job = playerData.job,
                charinfo = playerData.charinfo,
            } or nil,
        }
    end
    return {}
end

-- Send a message to the NUI.
-- @param action string
-- @param data any
function SendNUI(action, data)
    -- Happy path: hand the table straight to SendNUIMessage, which encodes it
    -- once. The previous implementation did a json.encode + json.decode
    -- round-trip to "sanitise" every payload AND a third json.encode for the
    -- debug log that ran even with debug off — i.e. up to 3 encodes per message.
    -- Now it's a single encode, with a sanitised fallback only if the send fails.
    if not pcall(_SendNUIMessage, { action = action, data = data }) then
        _SendNUIMessage({ action = action, data = safeFallback(action, data) })
    end

    -- Only pay the encode/format cost for logging when debug is actually on.
    if Config and Config.Debug then
        local ok, encoded = pcall(json.encode, data)
        ps.debug(('NUI Message Sent: %s%s'):format(action, (ok and encoded) and (' with data: ' .. encoded) or ''))
    end
end