local resourceName = tostring(GetCurrentResourceName())

RegisterNUICallback('deleteICU', function(data, cb)
    if not MDTOpen then
        cb({ success = false, message = 'MDT is not open' })
        return
    end

    if type(data) ~= 'table' or not data.id then
        cb({ success = false, message = 'Missing ICU record ID' })
        return
    end

    local result = ps.callback(resourceName .. ':server:deleteICU', data)
    cb(result or { success = false, message = 'Failed to delete ICU record' })
end)
