local _SendNUIMessage = SendNUIMessage

-- Send a message to the NUI
-- @param action string
-- @param data any
local function sanitizeNuiData(action, data)
    if data == nil then
        return nil
    end

    local ok, encoded = pcall(json.encode, data)
    if ok and encoded then
        local okDecode, decoded = pcall(json.decode, encoded)
        if okDecode then
            return decoded
        end
    end

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

function SendNUI(action, data)
    local safeData = sanitizeNuiData(action, data)
    if safeData ~= nil then
        _SendNUIMessage({
            action = action,
            data = safeData
        })
    else
        _SendNUIMessage({
            action = action
        })
    end
    if safeData then
        ps.debug(('NUI Message Sent: %s with data: %s'):format(action, json.encode(safeData)))
    else
        ps.debug(('NUI Message Sent: %s'):format(action))
    end
end
