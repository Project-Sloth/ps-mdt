RegisterNUICallback('getRoster', function(data, cb)
    if not MDTOpen then cb({}) return end
    local rosterList = ps.callback('ps-mdt:server:getRosterList')
    cb(rosterList)
end)

RegisterNUICallback('getOfficerTags', function(data, cb)
    if not MDTOpen then cb({}) return end
    local tags = ps.callback('ps-mdt:server:getOfficerTags')
    cb(tags or {})
end)

RegisterNUICallback('updateOfficerCertifications', function(data, cb)
    if not MDTOpen then cb({ success = false }) return end
    local result = ps.callback('ps-mdt:server:updateOfficerCertifications', data)
    cb(result or { success = false })
end)
