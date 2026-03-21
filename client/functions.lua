-- Dispatch Functions --

-- Get Recent Dispatch Calls
function GetRecentDispatch()
    local resourceName = tostring(GetCurrentResourceName())
    local ok, result = pcall(function()
        return ps.callback(resourceName .. ':server:getRecentDispatches')
    end)
    if ok and result then
        return result
    end
    return {}
end

AddEventHandler('QBCore:Client:OnPlayerLoaded', function()
    local check = ps.callback('ps-mdt:hasProfile')
end)