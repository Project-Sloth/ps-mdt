local resourceName = tostring(GetCurrentResourceName())

RegisterNUICallback('getNotes', function(_, cb)
    if not MDTOpen then
        cb({ success = false, message = 'MDT is not open' })
        return
    end

    local notes = ps.callback(resourceName .. ':server:getNotes')
    cb(notes or { success = false })
end)

RegisterNUICallback('saveNotes', function(data, cb)
    if not MDTOpen then
        cb({ success = false, message = 'MDT is not open' })
        return
    end

    local result = ps.callback(resourceName .. ':server:saveNotes', data or {})
    cb(result or { success = false })
end)
