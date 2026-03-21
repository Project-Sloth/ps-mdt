local impoundList = {}

-- IsCidFelon: checks if a citizen has felony charges
local function IsCidFelon(sentCid, cb)
    if not sentCid then
        if cb then cb(false) end
        return false
    end

    local felonyCount = MySQL.scalar.await([[
        SELECT COUNT(*)
        FROM mdt_reports_charges rc
        JOIN mdt_penal_codes pc ON rc.charge = pc.label
        WHERE rc.citizenid = ? AND pc.charge_class = 'felony'
    ]], { sentCid })

    local isFelon = (felonyCount and felonyCount > 0)
    if cb then cb(isFelon) end
    return isFelon
end

exports('IsCidFelon', IsCidFelon)

-- isRequestVehicle: checks in-memory impound list
local function isRequestVehicle(vehId)
    for i = #impoundList, 1, -1 do
        if impoundList[i] and impoundList[i]['vehicle'] == vehId then
            table.remove(impoundList, i)
            return true
        end
    end
    return false
end

exports('isRequestVehicle', isRequestVehicle)
