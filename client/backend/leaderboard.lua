local resourceName = tostring(GetCurrentResourceName())

RegisterNUICallback('getLeaderboard', function(data, cb)
    if not MDTOpen then cb({}) return end
    local leaderboard = ps.callback(resourceName .. ':server:getLeaderboard')
    cb(leaderboard or {})
end)
