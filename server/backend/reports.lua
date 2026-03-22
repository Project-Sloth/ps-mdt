local resourceName = tostring(GetCurrentResourceName())


local function collectCitizenIds(reportData)
    local citizenids = {}

    if reportData.involved then
        for _, involved in ipairs(reportData.involved) do
            if involved.citizenid then
                citizenids[involved.citizenid] = true
            end
        end
    end

    if reportData.charges then
        for _, charge in ipairs(reportData.charges) do
            if charge.citizenid then
                citizenids[charge.citizenid] = true
            end
        end
    end

    return citizenids
end

local function checkReportAccess(src, reportId)
    if not src or not reportId then
        return false
    end

    local identifier = ps.getIdentifier(src)
    local job = ps.getJobName(src)
    local jobType = ps.getJobType(src)

    if not identifier then
        return false
    end

    local hasAccess = MySQL.query.await([[
        SELECT mr.id
        FROM mdt_reports mr
        LEFT JOIN mdt_reports_restrictions mrr_check ON mr.id = mrr_check.reportid
        WHERE mr.id = ?
        AND (
            mrr_check.reportid IS NULL
            OR (mrr_check.type = 'citizenid' AND mrr_check.identifier = ?)
            OR (mrr_check.type = 'job' AND mrr_check.identifier = ?)
            OR (mrr_check.type = 'jobtype' AND mrr_check.identifier = ?)
        )
        GROUP BY mr.id
    ]], {reportId, identifier, job, jobType})

    return hasAccess and hasAccess[1] ~= nil
end

local function buildFullName(firstname, lastname, citizenid)
    local first = firstname and tostring(firstname) or ''
    local last = lastname and tostring(lastname) or ''
    local full = (first .. ' ' .. last):gsub('^%s+', ''):gsub('%s+$', '')
    if full ~= '' then
        return full
    end
    return ps.getPlayerNameByIdentifier(citizenid) or 'Unknown'
end




local function normalizeDateFilter(value)
    if not value then
        return nil
    end
    local year, month, day = tostring(value):match('^(%d%d%d%d)%-(%d%d)%-(%d%d)$')
    if not year then
        return nil
    end
    return ('%s-%s-%s'):format(year, month, day)
end

local function buildReportFilterClause(filters)
	local clauses = {}
	local values = {}
	if not filters then
		return '', values
	end

	local function hasValue(value)
		if value == nil then
			return false
		end
		if json and value == json.null then
			return false
		end
		if type(value) == 'string' then
			return value:gsub('%s+', '') ~= ''
		end
		return true
	end

	if hasValue(filters.type) then
		clauses[#clauses + 1] = 'mr.type = ?'
		values[#values + 1] = filters.type
	end

	if hasValue(filters.author) then
		local likeQuery = '%' .. tostring(filters.author) .. '%'
		clauses[#clauses + 1] = '(mr.authorplaintext LIKE ? OR mr.author LIKE ?)'
		values[#values + 1] = likeQuery
		values[#values + 1] = likeQuery
	end

    local startDate = normalizeDateFilter(filters.startDate)
    if startDate then
        clauses[#clauses + 1] = 'mr.datecreated >= CONCAT(?, " 00:00:00")'
        values[#values + 1] = startDate
    end

    local endDate = normalizeDateFilter(filters.endDate)
    if endDate then
        clauses[#clauses + 1] = 'mr.datecreated <= CONCAT(?, " 23:59:59")'
        values[#values + 1] = endDate
    end

    if #clauses == 0 then
        return '', values
    end

    return ' AND ' .. table.concat(clauses, ' AND '), values
end

local function buildReportAnalyticsClause(filters)
	local clauses = {}
	local values = {}
	if not filters then
		return '', values
	end

	local function hasValue(value)
		if value == nil then
			return false
		end
		if json and value == json.null then
			return false
		end
		if type(value) == 'string' then
			return value:gsub('%s+', '') ~= ''
		end
		return true
	end

	if hasValue(filters.author) then
		local likeQuery = '%' .. tostring(filters.author) .. '%'
		clauses[#clauses + 1] = '(mr.authorplaintext LIKE ? OR mr.author LIKE ?)'
		values[#values + 1] = likeQuery
		values[#values + 1] = likeQuery
	end

    local startDate = normalizeDateFilter(filters.startDate)
    if startDate then
        clauses[#clauses + 1] = 'mr.datecreated >= CONCAT(?, " 00:00:00")'
        values[#values + 1] = startDate
    end

    local endDate = normalizeDateFilter(filters.endDate)
    if endDate then
        clauses[#clauses + 1] = 'mr.datecreated <= CONCAT(?, " 23:59:59")'
        values[#values + 1] = endDate
    end

    if #clauses == 0 then
        return '', values
    end

    return ' AND ' .. table.concat(clauses, ' AND '), values
end

local function buildReportAccessClause()
    return [[
        (
            (mrr.reportid IS NULL AND ? = 'leo')
            OR (mrr.type = 'citizenid' AND mrr.identifier = ?)
            OR (mrr.type = 'job' AND mrr.identifier = ?)
            OR (mrr.type = 'jobtype' AND mrr.identifier = ?)
        )
    ]]
end


ps.registerCallback(resourceName .. ':server:getReports', function(source, page, filters)
	local src = source
	if not CheckAuth(src) then return end

    local identifier = ps.getIdentifier(src)
    local job = ps.getJobName(src)
    local jobType = ps.getJobType(src)

	local pageNumber = tonumber(page) or 1
	pageNumber = math.max(1, pageNumber)
	local limit = 20
	local offset = (pageNumber - 1) * limit


	local filterClause, filterValues = buildReportFilterClause(filters)
	filterClause = filterClause or ''

	local reportsQuery = ([[
		SELECT
			mr.id,
			mr.id as reportId,
			mr.title,
			mr.type,
			mr.contentyjs,
			mr.contentplaintext,
			mr.author,
			mr.authorplaintext,
			mr.datecreated,
			mr.dateupdated,
			(SELECT mrt.tag FROM mdt_reports_tags mrt WHERE mrt.reportid = mr.id LIMIT 1) as tag,
			(SELECT COUNT(*) FROM mdt_reports_tags mrt WHERE mrt.reportid = mr.id) as tagCount
		FROM
			mdt_reports AS mr
		LEFT JOIN
			mdt_reports_restrictions AS mrr ON mr.id = mrr.reportid
		WHERE
			%s%s
		GROUP BY
			mr.id
		ORDER BY
			mr.datecreated DESC
		LIMIT %d
		OFFSET %d
	]]):format(buildReportAccessClause(), filterClause, limit, offset)
	local params = { jobType, identifier, job, jobType }
	for _, value in ipairs(filterValues or {}) do
		params[#params + 1] = value
	end
	local reports = MySQL.query.await(reportsQuery, params)
	return reports
end)

ps.registerCallback(resourceName..':server:getReport', function(source, reportid)
    local src = source
	if not CheckAuth(src) then return end

	local identifier = ps.getIdentifier(src)
    local job = ps.getJobName(src)
    local jobType = ps.getJobType(src)

    local result = MySQL.query.await([[
        SELECT
            mr.*,
            (SELECT JSON_ARRAYAGG(
                JSON_OBJECT(
                    'citizenid', mri.citizenid,
                    'type', mri.type,
                    'notes', mri.notes,
                    'warrantActive', CASE
                        WHEN mri.type = 'suspect' AND EXISTS(
                            SELECT 1 FROM mdt_reports_warrants mw
                            WHERE mw.reportid = mr.id AND mw.citizenid = mri.citizenid AND mw.expirydate >= NOW()
                        ) THEN true
                        ELSE false
                    END
                )
            ) FROM mdt_reports_involved mri WHERE mri.reportid = mr.id) as involved,
            (SELECT JSON_ARRAYAGG(
                JSON_OBJECT(
                    'citizenid', mrc.citizenid,
                    'charge', mrc.charge,
                    'count', mrc.count,
                    'time', mrc.time,
                    'fine', mrc.fine
                )
            ) FROM mdt_reports_charges mrc WHERE mrc.reportid = mr.id) as charges,
            (SELECT JSON_ARRAYAGG(
                JSON_OBJECT(
                    'type', mre.type,
                    'content', mre.content,
                    'note', mre.note,
                    'stored', mre.stored
                )
            ) FROM mdt_reports_evidence mre WHERE mre.reportid = mr.id) as evidence,
            (SELECT JSON_ARRAYAGG(
                JSON_OBJECT(
                    'type', mrr.type,
                    'identifier', mrr.identifier
                )
            ) FROM mdt_reports_restrictions mrr WHERE mrr.reportid = mr.id) as restrictions,
            (SELECT JSON_ARRAYAGG(
                JSON_OBJECT(
                    'tag', mrt.tag
                )
            ) FROM mdt_reports_tags mrt WHERE mrt.reportid = mr.id) as tags,
            (SELECT JSON_ARRAYAGG(
                JSON_OBJECT(
                    'plate', mrv.plate,
                    'vehicle_label', mrv.vehicle_label,
                    'owner_name', mrv.owner_name,
                    'owner_citizenid', mrv.owner_citizenid
                )
            ) FROM mdt_report_vehicles mrv WHERE mrv.reportid = mr.id) as vehicles
        FROM mdt_reports mr
        WHERE mr.id = ?
    ]], {reportid})

    local report = result[1] or nil
    if not report then return nil end

    -- Post-process: resolve names and profile images for involved persons
    local enrichOk, enrichErr = pcall(function()
        local involved = report.involved
        if type(involved) == 'string' then
            local ok, decoded = pcall(json.decode, involved)
            if ok then involved = decoded end
        end

        if type(involved) ~= 'table' or #involved == 0 then return end

        -- Collect unique citizenids
        local cids = {}
        for _, entry in ipairs(involved) do
            if entry and entry.citizenid and entry.citizenid ~= '' then
                cids[entry.citizenid] = true
            end
        end

        local cidList = {}
        for cid in pairs(cids) do
            cidList[#cidList + 1] = cid
        end

        if #cidList > 0 then
            local placeholders = string.rep('?,', #cidList):sub(1, -2)
            local lookupQuery = ([[
                SELECT
                    p.citizenid,
                    CONCAT(
                        JSON_UNQUOTE(JSON_EXTRACT(p.charinfo, '$.firstname')),
                        ' ',
                        JSON_UNQUOTE(JSON_EXTRACT(p.charinfo, '$.lastname'))
                    ) as fullname,
                    mp.profilepicture as image
                FROM players p
                LEFT JOIN mdt_profiles mp ON mp.citizenid COLLATE utf8mb4_general_ci = p.citizenid COLLATE utf8mb4_general_ci
                WHERE p.citizenid COLLATE utf8mb4_general_ci IN (%s)
            ]]):format(placeholders)

            local lookupRows = MySQL.query.await(lookupQuery, cidList)
            local cidInfo = {}
            if lookupRows then
                for _, row in ipairs(lookupRows) do
                    cidInfo[row.citizenid] = { name = row.fullname, image = row.image }
                end
            end

            for _, entry in ipairs(involved) do
                if entry and entry.citizenid and cidInfo[entry.citizenid] then
                    local info = cidInfo[entry.citizenid]
                    entry.name = info.name or entry.name
                    entry.image = info.image
                end
            end
        end

        report.involved = json.encode(involved)
    end)

    if not enrichOk then
        ps.warn(('[getReport] Failed to enrich involved data: %s'):format(tostring(enrichErr)))
    end

    return report
end)

ps.registerCallback(resourceName .. ':server:searchPlayers', function(source, query)
    local src = source
    if not CheckAuth(src) then return end

    if not query or query == '' then
        return {}
    end

    if ps.auditLog then
        ps.auditLog(src, 'search_players', 'search', nil, {
            query = query
        })
    end

    local likeQuery = '%' .. query .. '%'

    local rows = MySQL.query.await([[
        SELECT
            p.citizenid,
            JSON_UNQUOTE(JSON_EXTRACT(p.charinfo, '$.firstname')) as firstname,
            JSON_UNQUOTE(JSON_EXTRACT(p.charinfo, '$.lastname')) as lastname,
            JSON_UNQUOTE(JSON_EXTRACT(p.metadata, '$.fingerprint')) as fingerprint,
            mp.profilepicture
        FROM players p
        LEFT JOIN mdt_profiles mp ON mp.citizenid COLLATE utf8mb4_general_ci = p.citizenid COLLATE utf8mb4_general_ci
        WHERE (
            p.citizenid LIKE ?
            OR JSON_UNQUOTE(JSON_EXTRACT(p.charinfo, '$.firstname')) LIKE ?
            OR JSON_UNQUOTE(JSON_EXTRACT(p.charinfo, '$.lastname')) LIKE ?
            OR CONCAT(
                JSON_UNQUOTE(JSON_EXTRACT(p.charinfo, '$.firstname')),
                ' ',
                JSON_UNQUOTE(JSON_EXTRACT(p.charinfo, '$.lastname'))
            ) LIKE ?
        )
        LIMIT 25
    ]], { likeQuery, likeQuery, likeQuery, likeQuery })

    local results = {}
    for _, row in ipairs(rows or {}) do
        local fullName = buildFullName(row.firstname, row.lastname, row.citizenid)
        local fingerprint = (row.fingerprint and row.fingerprint ~= 'null') and row.fingerprint or nil
        table.insert(results, {
            id = row.citizenid,
            citizenid = row.citizenid,
            fullName = fullName,
            fingerprint = fingerprint,
            image = row.profilepicture or nil,
        })
    end

    return results
end)

ps.registerCallback(resourceName .. ':server:searchOfficers', function(source, query)
    local src = source
    if not CheckAuth(src) then return end

    if not query or query == '' then
        return {}
    end

    query = tostring(query)
    if #query < 2 then
        return {}
    end

    if ps.auditLog then
        ps.auditLog(src, 'search_officers', 'search', nil, {
            query = query
        })
    end

    local likeQuery = '%' .. query .. '%'

    local rows = MySQL.query.await([[
        SELECT
            p.citizenid,
            JSON_UNQUOTE(JSON_EXTRACT(p.charinfo, '$.firstname')) as firstname,
            JSON_UNQUOTE(JSON_EXTRACT(p.charinfo, '$.lastname')) as lastname,
            JSON_UNQUOTE(JSON_EXTRACT(p.job, '$.name')) as jobname,
            JSON_UNQUOTE(JSON_EXTRACT(p.job, '$.grade.name')) as jobgrade,
            JSON_UNQUOTE(JSON_EXTRACT(p.job, '$.type')) as jobtype,
            mp.callsign as callsign
        FROM players p
        LEFT JOIN mdt_profiles mp ON mp.citizenid COLLATE utf8mb4_general_ci = p.citizenid COLLATE utf8mb4_general_ci
        WHERE (
            p.citizenid LIKE ?
            OR JSON_UNQUOTE(JSON_EXTRACT(p.charinfo, '$.firstname')) LIKE ?
            OR JSON_UNQUOTE(JSON_EXTRACT(p.charinfo, '$.lastname')) LIKE ?
            OR CONCAT(
                JSON_UNQUOTE(JSON_EXTRACT(p.charinfo, '$.firstname')),
                ' ',
                JSON_UNQUOTE(JSON_EXTRACT(p.charinfo, '$.lastname'))
            ) LIKE ?
            OR mp.callsign COLLATE utf8mb4_general_ci LIKE ?
        )
        LIMIT 50
    ]], { likeQuery, likeQuery, likeQuery, likeQuery, likeQuery })

    local results = {}
    for _, row in ipairs(rows or {}) do
        if IsPoliceJob(row.jobname, row.jobtype) then
            local fullName = buildFullName(row.firstname, row.lastname, row.citizenid)
            table.insert(results, {
                id = row.citizenid,
                citizenid = row.citizenid,
                fullName = fullName,
                badgeId = row.callsign or nil,
                rank = row.jobgrade or nil
            })
        end
    end

    return results
end)

ps.registerCallback(resourceName .. ':server:searchVehiclesForReport', function(source, query)
    local src = source
    if not CheckAuth(src) then return {} end

    if not query or query == '' then
        return {}
    end

    local likeQuery = '%' .. query .. '%'

    local rows = MySQL.query.await([[
        SELECT
            pv.plate,
            pv.vehicle,
            pv.citizenid,
            CONCAT(
                JSON_UNQUOTE(JSON_EXTRACT(p.charinfo, '$.firstname')),
                ' ',
                JSON_UNQUOTE(JSON_EXTRACT(p.charinfo, '$.lastname'))
            ) as owner_name
        FROM player_vehicles pv
        LEFT JOIN players p ON p.citizenid COLLATE utf8mb4_general_ci = pv.citizenid COLLATE utf8mb4_general_ci
        WHERE (
            pv.plate LIKE ?
            OR CONCAT(
                JSON_UNQUOTE(JSON_EXTRACT(p.charinfo, '$.firstname')),
                ' ',
                JSON_UNQUOTE(JSON_EXTRACT(p.charinfo, '$.lastname'))
            ) LIKE ?
        )
        LIMIT 25
    ]], { likeQuery, likeQuery })

    local results = {}
    for _, row in ipairs(rows or {}) do
        local vehicleData = nil
        local ok, core = pcall(function()
            return exports['qb-core']:GetCoreObject()
        end)
        if ok and core and core.Shared and core.Shared.Vehicles then
            vehicleData = core.Shared.Vehicles[row.vehicle]
        end

        table.insert(results, {
            plate = row.plate and string.upper(row.plate) or 'UNKNOWN',
            vehicle_label = vehicleData and vehicleData.name or row.vehicle or 'Unknown',
            owner_name = row.owner_name or 'Unknown',
            owner_citizenid = row.citizenid or nil,
        })
    end

    return results
end)

ps.registerCallback(resourceName..':server:saveReport', function(source, reportData)
    local src = source
    if not CheckAuth(src) then return end

    local identifier = ps.getIdentifier(src)
    local playerName = ps.getPlayerName(src)
    local callsign = ps.getMetadata(src, 'callsign')

    local title = reportData.report and reportData.report.title
    if not title or title == "" then
        ps.notify(src, 'Failed to save Report: Needs a title', 'error')
        ps.warn('Report with missing/empty title from player: ' .. src .. ' Name: ' .. playerName)
        return { success = false, error = 'Report needs a title' }
    end

    local content = reportData.report and reportData.report.content
    if not content or content == "" then
        ps.notify(src, 'Failed to save Report: Needs content', 'error')
        ps.warn('Report with missing/empty content from player: ' .. src .. ' Name: ' .. playerName)
        return { success = false, error = 'Report needs content' }
    end

    -- Tags are required
    local tags = reportData.tags
    if not tags or type(tags) ~= 'table' or #tags == 0 then
        ps.notify(src, 'Failed to save Report: At least one tag is required', 'error')
        return { success = false, message = 'At least one tag is required' }
    end

    local reportId = reportData.report and tonumber(reportData.report.id) or nil
    local reportType = reportData.report and reportData.report.type or 'Incident Report'

    local citizenids = collectCitizenIds(reportData)

    for citizenid, _ in pairs(citizenids) do
        if not EnsureProfileExists(citizenid) then
            -- Profile creation failed but don't block the save - the citizen
            -- may be offline or from a different framework. The report can still
            -- reference them by citizenid and the profile will be created when
            -- they are next looked up.
            ps.warn(('[Profile Auto-Create Skipped] Player [%s] %s saving report with citizen %s who has no profile yet')
                :format(src, playerName, citizenid))
        end
    end

    if reportId then
        if not checkReportAccess(src, reportId) then
            ps.notify(src, 'Failed to save Report: Not found or no access', 'error')
            ps.warn(('[Failed to save] Player [%s] %s tried to save a report (%s), but it was not found or they do not have access.')
                :format(src, playerName, reportId))
            return { success = false, error = "Report not found or access denied" }
        end
    end

    if not reportId then
        local insertResult = MySQL.insert.await([[
            INSERT INTO mdt_reports (title, type, contentyjs, contentplaintext, author, authorplaintext)
            VALUES (?, ?, ?, ?, ?, ?)
        ]], {
            title,
            reportType,
            json.encode(content),
            type(content) == "string" and content or json.encode(content),
            identifier,
            (callsign or '') .. ' ' .. (playerName or 'Unknown')
        })

        if not insertResult then
            ps.notify(src, 'Failed to save Report', 'error')
            ps.warn(('[Failed to save] Player [%s] %s tried to save a report (new). Insert failed.')
                :format(src, playerName))
            return { success = false, error = 'Failed to insert report' }
        end
        reportId = insertResult
    else
        local updateSuccess = MySQL.update.await([[
            UPDATE mdt_reports
            SET title = ?, type = ?, contentyjs = ?, contentplaintext = ?, author = ?, authorplaintext = ?, dateupdated = CURRENT_TIMESTAMP
            WHERE id = ?
        ]], {
            title,
            reportType,
            json.encode(content),
            type(content) == "string" and content or json.encode(content),
            identifier,
            (callsign or '') .. ' ' .. (playerName or 'Unknown'),
            reportId
        })

        if not updateSuccess or updateSuccess == 0 then
            ps.notify(src, 'Failed to save Report', 'error')
            ps.warn(('[Failed to save] Player [%s] %s tried to save a report (%s). Update failed.')
                :format(src, playerName, reportId))
            return { success = false, error = 'Failed to update report' }
        end

        local cleanupQueries = {
            { query = "DELETE FROM mdt_reports_involved WHERE reportid = ?", values = { reportId } },
            { query = "DELETE FROM mdt_reports_charges WHERE reportid = ?", values = { reportId } },
            { query = "DELETE FROM mdt_reports_evidence WHERE reportid = ?", values = { reportId } },
            { query = "DELETE FROM mdt_reports_restrictions WHERE reportid = ?", values = { reportId } },
            { query = "DELETE FROM mdt_reports_tags WHERE reportid = ?", values = { reportId } },
            { query = "DELETE FROM mdt_report_vehicles WHERE reportid = ?", values = { reportId } },
            { query = "DELETE FROM mdt_arrests WHERE reportid = ?", values = { reportId } }
        }

        local cleanupOk, cleanupErr = pcall(function()
            return MySQL.transaction.await(cleanupQueries)
        end)
        if not cleanupOk then
            ps.warn(('[Cleanup Transaction Error] Report %s: %s'):format(reportId, tostring(cleanupErr)))
            return { success = false, error = "Failed to clean up old report data: " .. tostring(cleanupErr) }
        end
    end

    local attachmentQueries = {}
    local warrantCitizenIds = {}

    if reportData.involved and #reportData.involved > 0 then
        for _, involved in ipairs(reportData.involved) do
            table.insert(attachmentQueries, {
                query = "INSERT INTO mdt_reports_involved (reportid, citizenid, type, notes) VALUES (?, ?, ?, ?)",
                values = { reportId, involved.citizenid, involved.type, involved.notes }
            })
        end
    end

    if reportData.charges and #reportData.charges > 0 then
        for _, charge in ipairs(reportData.charges) do
            table.insert(attachmentQueries, {
                query = "INSERT INTO mdt_reports_charges (reportid, citizenid, charge, count, time, fine) VALUES (?, ?, ?, ?, ?, ?)",
                values = { reportId, charge.citizenid, charge.charge, charge.count or 1, charge.time, charge.fine }
            })
            if charge.warrant == true and charge.citizenid then
                warrantCitizenIds[charge.citizenid] = true
            end
        end
    end

    if reportData.evidence and #reportData.evidence > 0 then
        for _, evidence in ipairs(reportData.evidence) do
            table.insert(attachmentQueries, {
                query =
                "INSERT INTO mdt_reports_evidence (reportid, type, content, note, stored) VALUES (?, ?, ?, ?, ?)",
                values = { reportId, evidence.type, evidence.content, evidence.note, evidence.stored or 0 }
            })
        end
    end

    if reportData.restrictions and #reportData.restrictions > 0 then
        for _, restriction in ipairs(reportData.restrictions) do
            table.insert(attachmentQueries, {
                query = "INSERT INTO mdt_reports_restrictions (reportid, type, identifier) VALUES (?, ?, ?)",
                values = { reportId, restriction.type, restriction.identifier }
            })
        end
    end

    -- Auto-add jobtype restriction so reports are only visible to the same job type
    local creatorJobType = ps.getJobType(src)
    if creatorJobType then
        table.insert(attachmentQueries, {
            query = "INSERT INTO mdt_reports_restrictions (reportid, type, identifier) VALUES (?, ?, ?)",
            values = { reportId, 'jobtype', creatorJobType }
        })
    end

    if reportData.tags and #reportData.tags > 0 then
        for _, tag in ipairs(reportData.tags) do
            table.insert(attachmentQueries, {
                query = "INSERT INTO mdt_reports_tags (reportid, tag) VALUES (?, ?)",
                values = { reportId, tag.tag }
            })
        end
    end

    if reportData.vehicles and #reportData.vehicles > 0 then
        for _, vehicle in ipairs(reportData.vehicles) do
            table.insert(attachmentQueries, {
                query = "INSERT INTO mdt_report_vehicles (reportid, plate, vehicle_label, owner_name, owner_citizenid) VALUES (?, ?, ?, ?, ?)",
                values = { reportId, vehicle.plate, vehicle.vehicle_label, vehicle.owner_name, vehicle.owner_citizenid }
            })
        end
    end

    if #attachmentQueries > 0 then
        local attachOk, attachErr = pcall(function()
            return MySQL.transaction.await(attachmentQueries)
        end)
        if not attachOk then
            ps.warn(('[Attachment Transaction Error] Report %s: %s'):format(reportId, tostring(attachErr)))
            return { success = false, error = "Failed to save report attachments: " .. tostring(attachErr) }
        end
    end

    if reportId and reportType == 'Arrest Report' and reportData.involved and #reportData.involved > 0 then
        local officerId = ps.getIdentifier(src)
        local officerName = (callsign or '') .. ' ' .. (playerName or '')
        officerName = officerName:gsub('^%s+', ''):gsub('%s+$', '')
        local arrestQueries = {}
        for _, involved in ipairs(reportData.involved) do
            if involved.type == 'suspect' and involved.citizenid then
                table.insert(arrestQueries, {
                    query = [[
                        INSERT INTO mdt_arrests (reportid, citizenid, officer_citizenid, officer_name)
                        VALUES (?, ?, ?, ?)
                    ]],
                    values = { reportId, involved.citizenid, officerId, officerName }
                })
            end
        end
        if #arrestQueries > 0 then
            MySQL.transaction.await(arrestQueries)
            if ps.auditLog then
                for _, involved in ipairs(reportData.involved) do
                    if involved.type == 'suspect' and involved.citizenid then
                        ps.auditLog(src, 'arrest_logged', 'arrest', reportId, {
                            citizenid = involved.citizenid,
                            reportId = reportId
                        })
                    end
                end
            end
        end
    end

    if reportId and next(warrantCitizenIds) ~= nil then
        local expiryDate = os.date('%Y-%m-%d %H:%M:%S', os.time() + (7 * 24 * 60 * 60))
        local warrantQueries = {}
        for citizenid, _ in pairs(warrantCitizenIds) do
            table.insert(warrantQueries, {
                query = [[
                    INSERT INTO mdt_reports_warrants (reportid, citizenid, felonies, misdemeanors, infractions, expirydate)
                    VALUES (?, ?, 0, 0, 0, ?)
                    ON DUPLICATE KEY UPDATE expirydate = VALUES(expirydate)
                ]],
                values = { reportId, citizenid, expiryDate }
            })
        end
        MySQL.transaction.await(warrantQueries)
    end

    Cache.invalidatePrefix('reports:analytics:')

    if ps.auditLog then
        local action = reportId and reportData.report and reportData.report.id and 'report_updated' or 'report_created'
        ps.auditLog(src, action, 'report', reportId, {
            title = title,
            type = reportType
        })
    end

    Cache.invalidate('dashboard:reportStats')
    Cache.invalidate('dashboard:usageMetrics')
    return {
        success = true,
        reportId = reportId,
        message = reportId and "Report updated successfully" or "Report created successfully"
    }
end)

ps.registerCallback(resourceName..':server:updateReportContent', function(source, reportid, content, reportData)
    local src = source
    if not CheckAuth(src) then return { success = false, error = "Unauthorized" } end

    if not content then
        return { success = false, error = "Missing content" }
    end

    local reportId = reportid and tonumber(reportid) or nil
    local title = (reportData and reportData.title) or "Draft Report"
    local reportType = (reportData and reportData.type) or "Incident Report"

    local identifier = ps.getIdentifier(src)
    local playerName = ps.getPlayerName(src)
    local callsign = ps.getMetadata(src, 'callsign')

    if not identifier then return { success = false, error = "Player not found" } end

    if reportId then
        if not checkReportAccess(src, reportId) then
            return { success = false, error = "Report not found or access denied" }
        end
    end

    if not reportId then
        local insertResult = MySQL.insert.await([[
            INSERT INTO mdt_reports (title, type, contentyjs, contentplaintext, author, authorplaintext)
            VALUES (?, ?, ?, ?, ?, ?)
        ]], {
            title,
            reportType,
            json.encode(content),
            type(content) == "string" and content or json.encode(content),
            identifier,
            callsign .. ' ' .. playerName
        })

        if not insertResult then
            return { success = false, error = "Failed to save content" }
        end

        return {
            success = true,
            reportId = insertResult,
            message = "Content saved successfully",
            isNewReport = true
        }
    end

    local updateSuccess = MySQL.update.await([[
        UPDATE mdt_reports
        SET contentyjs = ?, contentplaintext = ?, dateupdated = CURRENT_TIMESTAMP
        WHERE id = ?
    ]], {
        json.encode(content),
        type(content) == "string" and content or json.encode(content),
        reportId
    })

    if updateSuccess and updateSuccess > 0 then
        return {
            success = true,
            reportId = reportId,
            message = "Content saved successfully",
            isNewReport = false
        }
    end

    return { success = false, error = "Failed to save content" }
end)

ps.registerCallback(resourceName..':server:deleteReport', function(source, reportId)
    local src = source
    if not CheckAuth(src) then return end

    reportId = tonumber(reportId)
    if not reportId then
        return { success = false, error = "Missing/Invalid report ID" }
    end

    local playerName = ps.getPlayerName(src)

    if not checkReportAccess(src, reportId) then
        ps.notify(src, 'Failed to delete Report: Not found or no access', 'error')
        ps.warn(('[Failed to delete] Player [%s] %s tried to delete a report (%s), but it was not found or they do not have access.')
            :format(src, playerName, reportId))
        return { success = false, error = "Report not found or access denied" }
    end

    local reportInfo = MySQL.query.await("SELECT title FROM mdt_reports WHERE id = ?", { reportId })
    local reportTitle = reportInfo and reportInfo[1] and reportInfo[1].title or "Unknown"

    local success = MySQL.query.await("DELETE FROM mdt_reports WHERE id = ?", { reportId })

    if success then
        Cache.invalidate('dashboard:reportStats')
        Cache.invalidate('dashboard:usageMetrics')
        ps.notify(src, 'Report deleted successfully', 'success')
        ps.debug(('[Report Deleted] Player [%s] %s successfully deleted report (%s): "%s"')
            :format(src, playerName, reportId, reportTitle))

        if ps.auditLog then
            ps.auditLog(src, 'report_deleted', 'report', reportId, {
                title = reportTitle
            })
        end

        return {
            success = true,
            message = "Report deleted successfully",
            reportId = reportId
        }
    else
        ps.notify(src, 'Failed to delete report', 'error')
        ps.warn(('[Failed to delete] Player [%s] %s tried to delete report (%s). Database query failed.')
            :format(src, playerName, reportId))

        return {
            success = false,
            error = "Failed to delete report from database"
        }
    end
end)

ps.registerCallback(resourceName..':server:getAvailableTags', function(source, playerJobType)
    local src = source
    if not CheckAuth(src) then return end

    local jt = playerJobType or 'leo'

    -- Pull from master mdt_tags table (report + both types) filtered by job_type
    local tags = MySQL.query.await([[
        SELECT t.name, t.color,
               (SELECT COUNT(*) FROM mdt_reports_tags rt WHERE rt.tag = t.name) AS usage_count
        FROM mdt_tags t
        WHERE t.type IN ('report', 'both')
          AND (t.job_type = ? OR t.job_type = 'all')
        ORDER BY t.name ASC
    ]], { jt })

    return tags or {}
end)

ps.registerCallback(resourceName..':server:generateReportId', function(source)
    local src = source
    if not CheckAuth(src) then return end

    return {
        success = true,
        reportId = nil
    }
end)

ps.registerCallback(resourceName..':server:getReportAnalytics', function(source, filters)
    local src = source
    if not CheckAuth(src) then return { success = false, error = "Unauthorized" } end

    local identifier = ps.getIdentifier(src)
    local job = ps.getJobName(src)
    local jobType = ps.getJobType(src)

    local filterClause, filterValues = buildReportFilterClause(filters)
    filterClause = filterClause or ''

	local accessClause = buildReportAccessClause()
    local cacheKeyParts = {
        identifier or '',
        job or '',
        jobType or '',
        filters and tostring(filters.startDate) or '',
        filters and tostring(filters.endDate) or '',
        filters and tostring(filters.author) or '',
    }
    local cacheKey = 'reports:analytics:' .. table.concat(cacheKeyParts, '|')

    local cached = Cache.get(cacheKey)
    if cached then
        return { success = true, data = cached }
    end

	local incidentQuery = ([[
        SELECT COUNT(*) AS total
        FROM mdt_reports AS mr
        LEFT JOIN mdt_reports_restrictions AS mrr ON mr.id = mrr.reportid
        WHERE %s%s
          AND mr.type = 'Incident Report'
	]]):format(accessClause, filterClause)
	local incidentParams = { jobType, identifier, job, jobType }
	for _, value in ipairs(filterValues or {}) do
		incidentParams[#incidentParams + 1] = value
	end
	local incidentRow = MySQL.single.await(incidentQuery, incidentParams)

	local arrestQuery = ([[
        SELECT COUNT(*) AS total
        FROM mdt_arrests AS ma
        INNER JOIN mdt_reports AS mr ON mr.id = ma.reportid
        LEFT JOIN mdt_reports_restrictions AS mrr ON mr.id = mrr.reportid
        WHERE %s%s
	]]):format(accessClause, filterClause)
	local arrestParams = { jobType, identifier, job, jobType }
	for _, value in ipairs(filterValues or {}) do
		arrestParams[#arrestParams + 1] = value
	end
	local arrestRow = MySQL.single.await(arrestQuery, arrestParams)

	local warrantQuery = ([[
        SELECT COUNT(*) AS total
        FROM mdt_reports_warrants AS mw
        INNER JOIN mdt_reports AS mr ON mr.id = mw.reportid
        LEFT JOIN mdt_reports_restrictions AS mrr ON mr.id = mrr.reportid
        WHERE %s%s
          AND mw.expirydate >= NOW()
	]]):format(accessClause, filterClause)
	local warrantParams = { jobType, identifier, job, jobType }
	for _, value in ipairs(filterValues or {}) do
		warrantParams[#warrantParams + 1] = value
	end
	local warrantRow = MySQL.single.await(warrantQuery, warrantParams)

    local data = {
        incidents = tonumber(incidentRow and incidentRow.total) or 0,
        arrests = tonumber(arrestRow and arrestRow.total) or 0,
        warrants = tonumber(warrantRow and warrantRow.total) or 0,
    }

    Cache.set(cacheKey, data, 15)

    return {
        success = true,
        data = data
    }
end)

ps.registerCallback(resourceName .. ':server:getReportsByPlate', function(source, plate)
    local src = source
    if not CheckAuth(src) then return {} end

    if not plate or plate == '' then
        return {}
    end

    local rows = MySQL.query.await([[
        SELECT
            mr.id,
            mr.title,
            mr.type,
            mr.datecreated,
            mr.authorplaintext
        FROM mdt_report_vehicles mrv
        INNER JOIN mdt_reports mr ON mr.id = mrv.reportid
        WHERE mrv.plate = ?
        ORDER BY mr.datecreated DESC
        LIMIT 20
    ]], { plate })

    return rows or {}
end)
