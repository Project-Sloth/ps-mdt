local resourceName = tostring(GetCurrentResourceName())

-- Send to Jail
RegisterNUICallback('sendToJail', function(data, cb)
    if not MDTOpen then
        cb({ success = false, message = 'MDT is not open' })
        return
    end

    if type(data) ~= 'table' or not data.citizenId or not data.sentence then
        cb({ success = false, message = 'Missing citizen ID or sentence' })
        return
    end

    local result = ps.callback(resourceName .. ':server:sendToJail', data)
    cb(result or { success = false, message = 'Failed to send to jail' })
end)

-- Give Citation
RegisterNUICallback('giveCitation', function(data, cb)
    if not MDTOpen then
        cb({ success = false, message = 'MDT is not open' })
        return
    end

    if type(data) ~= 'table' or not data.citizenId then
        cb({ success = false, message = 'Missing citizen ID' })
        return
    end

    local result = ps.callback(resourceName .. ':server:giveCitation', data)
    cb(result or { success = false, message = 'Failed to give citation' })
end)
