local resourceName = tostring(GetCurrentResourceName())

RegisterNUICallback('getReports', function(data, cb)
    if not MDTOpen then
        cb({ success = false, message = 'MDT is not open' })
        return
    end

    data = data or {}
    local page = tonumber(data.page) or 1
    page = math.max(1, page)
    local filters = data and data.filters or nil
    local reports = ps.callback(resourceName .. ':server:getReports', page, filters)

    if reports then
        local response = {
            reports = reports,
            hasMore = #reports >= 20
        }
        cb(response)
    else
        cb({ reports = {}, hasMore = false })
    end
end)

RegisterNUICallback('getReportAnalytics', function(data, cb)
    if not MDTOpen then
        cb({ success = false, message = 'MDT is not open' })
        return
    end

    local filters = data and data.filters or nil
    local result = ps.callback(resourceName .. ':server:getReportAnalytics', filters)
    cb(result or { success = false })
end)

RegisterNUICallback('getReport', function(data, cb)
    if not MDTOpen then
        cb({ success = false, message = 'MDT is not open' })
        return
    end

    if not data or not data.reportId then
        cb({ success = false, message = 'Missing report ID' })
        return
    end

    local report = ps.callback(resourceName .. ':server:getReport', data.reportId)
    if report then
        cb({ success = true, data = report })
    else
        cb({ success = false, message = 'Report not found or access denied' })
    end
end)

RegisterNUICallback('saveReport', function(data, cb)
    if not MDTOpen then
        cb({ success = false, message = 'MDT is not open' })
        return
    end

    if not data or not data.reportId then
        ps.error('Missing report data in request')
        cb({ success = false, message = 'Missing report data' })
        return
    end

    local involved = {}
    if data.involved then
        if data.involved.suspects then
            for _, suspect in ipairs(data.involved.suspects) do
                if suspect.citizenid then
                    table.insert(involved, {
                        citizenid = suspect.citizenid,
                        type = 'suspect',
                        notes = suspect.notes or ''
                    })
                end
            end
        end
        if data.involved.victims then
            for _, victim in ipairs(data.involved.victims) do
                if victim.citizenid then
                    table.insert(involved, {
                        citizenid = victim.citizenid,
                        type = 'victim',
                        notes = ''
                    })
                end
            end
        end
        if data.involved.officers then
            for _, officer in ipairs(data.involved.officers) do
                if officer.citizenid or officer.id then
                    table.insert(involved, {
                        citizenid = officer.citizenid or officer.id,
                        type = 'officer',
                        notes = officer.notes or ''
                    })
                end
            end
        end
    end

    local evidence = {}
    if data.evidence then
        for _, item in ipairs(data.evidence) do
            table.insert(evidence, {
                type = item.type or 'Evidence',
                content = item.serial or (item.images and item.images[1]) or item.title or '',
                note = item.notes or ''
            })
        end
    end

    local tags = {}
    if data.tags then
        for _, tag in ipairs(data.tags) do
            if tag then
                table.insert(tags, { tag = tag })
            end
        end
    end

    local charges = {}
    if data.charges then
        for _, charge in ipairs(data.charges) do
            if charge.citizenid and charge.charge then
                table.insert(charges, {
                    citizenid = charge.citizenid,
                    charge = charge.charge,
                    count = charge.count or 1,
                    time = charge.time or 0,
                    fine = charge.fine or 0
                })
            end
        end
    end

    local restrictions = {}
    if data.restrictions then
        for _, restriction in ipairs(data.restrictions) do
            if type(restriction) == 'string' then
                table.insert(restrictions, { type = 'job', identifier = restriction })
            elseif type(restriction) == 'table' then
                table.insert(restrictions, {
                    type = restriction.type or 'job',
                    identifier = restriction.identifier or restriction
                })
            end
        end
    end

    local reportPayload = {
        id = data.id or data.reportId,
        reportId = data.reportId,
        title = data.title,
        type = data.type,
        content = data.content
    }

    local vehicles = {}
    if data.vehicles then
        for _, vehicle in ipairs(data.vehicles) do
            table.insert(vehicles, {
                plate = vehicle.plate,
                vehicle_label = vehicle.vehicle_label,
                owner_name = vehicle.owner_name,
                owner_citizenid = vehicle.owner_citizenid
            })
        end
    end

    local result = ps.callback(resourceName .. ':server:saveReport', {
        report = reportPayload,
        involved = involved,
        evidence = evidence,
        charges = charges,
        tags = tags,
        restrictions = restrictions,
        vehicles = vehicles
    })
    if result and result.success then
        cb({
            success = true,
            message = result.message,
            reportId = result.reportId
        })
    else
        cb({
            success = false,
            message = result and result.error or 'Failed to save report'
        })
    end
end)

RegisterNUICallback('updateReportContent', function(data, cb)
    if not MDTOpen then
        cb({ success = false, message = 'MDT is not open' })
        return
    end

    if not data.content then
        cb({ success = false, message = 'Missing content' })
        return
    end

    local result = ps.callback(resourceName .. ':server:updateReportContent', data.reportId, data.content, data.reportData)
    if result and result.success then
        cb({
            success = true,
            message = result.message,
            reportId = result.reportId,
            isNewReport = result.isNewReport
        })
    else
        cb({
            success = false,
            message = result and result.error or 'Failed to update content'
        })
    end
end)

RegisterNUICallback('deleteReport', function(data, cb)
    if not MDTOpen then
        cb({ success = false, message = 'MDT is not open' })
        return
    end

    if not data.reportId then
        cb({ success = false, message = 'Missing report ID' })
        return
    end

    local result = ps.callback(resourceName .. ':server:deleteReport', data.reportId)
    if result and result.success then
    cb({
        success = true,
        message = result.message,
        reportId = result.reportId
        })
    else
        cb({
            success = false,
            message = result and result.error or 'Failed to delete report'
        })
    end
end)

RegisterNUICallback('getAvailableTags', function(data, cb)
    if not MDTOpen then
        cb({ success = false, message = 'MDT is not open' })
        return
    end

    local jobType = ps.getJobType()
    local mdtJobType = jobType == Config.MedicalJobType and 'ems' or 'leo'
    local tags = ps.callback(resourceName .. ':server:getAvailableTags', mdtJobType)
    if tags then
        cb({ success = true, data = tags })
    else
        cb({ success = false, message = 'Failed to fetch available tags' })
    end
end)

RegisterNUICallback('generateReportId', function(data, cb)
    if not MDTOpen then
        cb({ success = false, message = 'MDT is not open' })
        return
    end

    local result = ps.callback(resourceName .. ':server:generateReportId')
    if result and result.success then
        cb({
            success = true,
            reportId = result.reportId
        })
    else
        cb({
            success = false,
            message = result and result.error or 'Failed to generate report ID'
        })
    end
end)

RegisterNUICallback('searchOfficers', function(data, cb)
    if not MDTOpen then
        cb({ success = false, message = 'MDT is not open', data = {} })
        return
    end

    local query = data and data.query or ''
    local result = ps.callback(resourceName .. ':server:searchOfficers', query)
    cb(result or {})
end)

RegisterNUICallback('searchPlayers', function(data, cb)
    if not MDTOpen then
        cb({ success = false, message = 'MDT is not open', data = {} })
        return
    end

    local query = data and data.query or ''
    local result = ps.callback(resourceName .. ':server:searchPlayers', query)
    cb(result or {})
end)

RegisterNUICallback('searchVehiclesForReport', function(data, cb)
    if not MDTOpen then
        cb({})
        return
    end

    local query = data and data.query or ''
    local result = ps.callback(resourceName .. ':server:searchVehiclesForReport', query)
    cb(result or {})
end)
