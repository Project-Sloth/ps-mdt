local resourceName = tostring(GetCurrentResourceName())

local function buildInClause(values)
    local placeholders = {}
    for i = 1, #values do
        placeholders[i] = '?'
    end
    return table.concat(placeholders, ',')
end

local function collectCitizenFlags(citizenids)
    local flagsByCid = {}
    if not citizenids or #citizenids == 0 then
        return flagsByCid
    end

    for i = 1, #citizenids do
        flagsByCid[citizenids[i]] = {}
    end

    local inClause = buildInClause(citizenids)

    -- Warrants (table may not exist yet)
    local wOk, warrantRows = pcall(MySQL.query.await, ([[
        SELECT citizenid
        FROM mdt_reports_warrants
        WHERE expirydate >= NOW()
        AND citizenid IN (%s)
        GROUP BY citizenid
    ]]):format(inClause), citizenids)

    if wOk then
        for _, row in ipairs(warrantRows or {}) do
            if row.citizenid then
                flagsByCid[row.citizenid] = flagsByCid[row.citizenid] or {}
                table.insert(flagsByCid[row.citizenid], 'Active Warrant')
            end
        end
    end

    -- BOLOs (table may not exist yet)
    local boloValues = { 'citizen', 'active' }
    for i = 1, #citizenids do
        boloValues[#boloValues + 1] = citizenids[i]
    end

    local bOk, boloRows = pcall(MySQL.query.await, ([[
        SELECT subject_id
        FROM mdt_bolos
        WHERE type = ? AND status = ?
        AND subject_id IN (%s)
    ]]):format(inClause), boloValues)

    if bOk then
        local boloSeen = {}
        for _, row in ipairs(boloRows or {}) do
            if row.subject_id and not boloSeen[row.subject_id] then
                boloSeen[row.subject_id] = true
                flagsByCid[row.subject_id] = flagsByCid[row.subject_id] or {}
                table.insert(flagsByCid[row.subject_id], 'Active Bolo')
            end
        end
    end

    return flagsByCid
end

local function getGender(gen)
    if gen == 0 then
        return 'Male'
    elseif gen == 1 then
        return 'Female'
    end
    return 'Unknown'
end

-- Safe query helper: returns empty table on error (handles missing tables gracefully)
local function safeQuery(query, params)
    local ok, rows = pcall(MySQL.query.await, query, params)
    if not ok then
        ps.warn('[getCitizens] Query failed (table may not exist): ' .. tostring(rows))
        return {}
    end
    return rows or {}
end

-- getCitizens - pulls citizens from database with pagination support
ps.registerCallback(resourceName .. ':server:getCitizens', function(source, page)
    local src = source
    if not CheckAuth(src) then return {} end
    local startTime = os.clock()
    page = page or 1 -- Default to page 1 if not provided
    local limit = Config.Pagination and Config.Pagination.Citizens or 20
    local offset = (page - 1) * limit

    -- Main query with pagination
    local query = [[
        SELECT mp.id, p.citizenid, JSON_UNQUOTE(JSON_EXTRACT(p.charinfo, '$.firstname')) AS firstname,
        JSON_UNQUOTE(JSON_EXTRACT(p.charinfo, '$.lastname')) AS lastname,
        JSON_UNQUOTE(JSON_EXTRACT(p.charinfo, '$.gender')) AS gender,
        JSON_UNQUOTE(JSON_EXTRACT(p.charinfo, '$.birthdate')) AS dateofbirth,
        JSON_UNQUOTE(JSON_EXTRACT(p.charinfo, '$.phone')) AS phone,
        JSON_UNQUOTE(JSON_EXTRACT(p.job, '$.label')) AS job
        FROM players AS p
        LEFT JOIN mdt_profiles AS mp
        ON CONVERT(p.citizenid USING utf8mb4) COLLATE utf8mb4_general_ci = CONVERT(mp.citizenid USING utf8mb4) COLLATE utf8mb4_general_ci
        LIMIT ? OFFSET ?
    ]]
    local result = safeQuery(query, { limit, offset })
    if not result or #result == 0 then return {} end

    local citizenids = {}
    for _, v in ipairs(result) do
        if v.citizenid then
            citizenids[#citizenids + 1] = v.citizenid
        end
    end

    -- Wrap flags in pcall since it queries mdt_reports_warrants / mdt_bolos which may not exist
    local ok, flagsByCid = pcall(collectCitizenFlags, citizenids)
    if not ok then
        ps.warn('[getCitizens] collectCitizenFlags failed: ' .. tostring(flagsByCid))
        flagsByCid = {}
    end

    -- Batch fetch profile pictures, property counts, vehicle counts, and arrest counts
    local profilePics = {}
    local propCounts = {}
    local vehCounts = {}
    local arrestCounts = {}

    if #citizenids > 0 then
        local inClause = buildInClause(citizenids)

        local profileRows = safeQuery(
            ('SELECT citizenid, profilepicture FROM mdt_profiles WHERE citizenid IN (%s)'):format(inClause),
            citizenids
        )
        for _, row in ipairs(profileRows) do
            if row.profilepicture and row.profilepicture ~= '' then
                profilePics[row.citizenid] = row.profilepicture
            end
        end

        local propRows = safeQuery(
            ('SELECT citizenid, COUNT(*) AS cnt FROM player_houses WHERE citizenid IN (%s) GROUP BY citizenid'):format(inClause),
            citizenids
        )
        for _, row in ipairs(propRows) do
            propCounts[row.citizenid] = tonumber(row.cnt) or 0
        end

        local vehRows = safeQuery(
            ('SELECT citizenid, COUNT(*) AS cnt FROM player_vehicles WHERE citizenid IN (%s) GROUP BY citizenid'):format(inClause),
            citizenids
        )
        for _, row in ipairs(vehRows) do
            vehCounts[row.citizenid] = tonumber(row.cnt) or 0
        end

        local arrestRows = safeQuery(
            ('SELECT citizenid, COUNT(*) AS cnt FROM mdt_arrests WHERE citizenid IN (%s) GROUP BY citizenid'):format(inClause),
            citizenids
        )
        for _, row in ipairs(arrestRows) do
            arrestCounts[row.citizenid] = tonumber(row.cnt) or 0
        end
    end

    for _, v in ipairs(result) do
        v.id = _
        v.cid = v.citizenid
        v.firstName = v.firstname
        v.lastName = v.lastname
        v.gender = getGender(tonumber(v.gender))
        v.dob = v.dateofbirth
        v.phone = v.phone
        v.image = profilePics[v.citizenid] or nil
        v.occupations = { v.job }
        v.properties = propCounts[v.citizenid] or 0
        v.vehicles = vehCounts[v.citizenid] or 0
        v.arrests = arrestCounts[v.citizenid] or 0
        v.flags = flagsByCid[v.citizenid] or {}
    end
    local endTime = os.clock()
    local elapsedTime = (endTime - startTime) * 1000
    ps.debug(string.format("getCitizens callback executed in %.2f ms for page %d", elapsedTime, page))

    if result[1] then
        ps.debug('[getCitizens] Sample citizen data structure:', result[1])
    end

    return result
end)

-- searchPlayers - searches the database for citizens by provided query (first/last name, citizenid, phone number, occupation)
-- Returns the same data structure as getCitizens but filtered by search query
ps.registerCallback(resourceName .. ':server:searchCitizens', function(source, query)
    local src = source
    if not CheckAuth(src) then return {} end
    local startTime = os.clock()

    if not query or string.len(query) < 2 then
        return {}
    end

    if ps.auditLog then
        ps.auditLog(src, 'search_citizens', 'search', nil, {
            query = query
        })
    end

    -- Sanitize the query for SQL LIKE operations
    local searchTerm = '%' .. query:lower() .. '%'

    -- Build a complex search query that searches across multiple fields and returns same data as getCitizens
    local sqlQuery = [[
        SELECT DISTINCT
            mp.id,
            p.citizenid,
            JSON_UNQUOTE(JSON_EXTRACT(p.charinfo, '$.firstname')) AS firstname,
            JSON_UNQUOTE(JSON_EXTRACT(p.charinfo, '$.lastname')) AS lastname,
            JSON_UNQUOTE(JSON_EXTRACT(p.charinfo, '$.gender')) AS gender,
            JSON_UNQUOTE(JSON_EXTRACT(p.charinfo, '$.birthdate')) AS dateofbirth,
            JSON_UNQUOTE(JSON_EXTRACT(p.charinfo, '$.phone')) AS phone,
            JSON_UNQUOTE(JSON_EXTRACT(p.job, '$.label')) AS job
        FROM players AS p
        LEFT JOIN mdt_profiles AS mp ON p.citizenid COLLATE utf8mb4_general_ci = mp.citizenid COLLATE utf8mb4_general_ci
        WHERE 
            LOWER(JSON_UNQUOTE(JSON_EXTRACT(p.charinfo, '$.firstname'))) LIKE ? OR
            LOWER(JSON_UNQUOTE(JSON_EXTRACT(p.charinfo, '$.lastname'))) LIKE ? OR
            LOWER(CONCAT(JSON_UNQUOTE(JSON_EXTRACT(p.charinfo, '$.firstname')), ' ', JSON_UNQUOTE(JSON_EXTRACT(p.charinfo, '$.lastname')))) LIKE ? OR
            LOWER(p.citizenid) LIKE ? OR
            LOWER(JSON_UNQUOTE(JSON_EXTRACT(p.charinfo, '$.phone'))) LIKE ? OR
            LOWER(JSON_UNQUOTE(JSON_EXTRACT(p.job, '$.label'))) LIKE ?
        LIMIT ?
    ]]

    local searchLimit = Config.Pagination and Config.Pagination.CitizenSearch or 20
    local result = safeQuery(sqlQuery, {
        searchTerm, searchTerm, searchTerm, searchTerm, searchTerm, searchTerm, searchLimit
    })
    if not result or #result == 0 then return {} end

    -- Process results to match getCitizens format exactly
    local citizenids = {}
    for _, v in ipairs(result) do
        if v.citizenid then
            citizenids[#citizenids + 1] = v.citizenid
        end
    end

    local ok, flagsByCid = pcall(collectCitizenFlags, citizenids)
    if not ok then
        ps.warn('[searchCitizens] collectCitizenFlags failed: ' .. tostring(flagsByCid))
        flagsByCid = {}
    end

    -- Batch fetch profile pictures, property counts, vehicle counts, and arrest counts
    local profilePics = {}
    local propCounts = {}
    local vehCounts = {}
    local arrestCounts = {}

    if #citizenids > 0 then
        local inClause = buildInClause(citizenids)

        local profileRows = safeQuery(
            ('SELECT citizenid, profilepicture FROM mdt_profiles WHERE citizenid IN (%s)'):format(inClause),
            citizenids
        )
        for _, row in ipairs(profileRows) do
            if row.profilepicture and row.profilepicture ~= '' then
                profilePics[row.citizenid] = row.profilepicture
            end
        end

        local propRows = safeQuery(
            ('SELECT citizenid, COUNT(*) AS cnt FROM player_houses WHERE citizenid IN (%s) GROUP BY citizenid'):format(inClause),
            citizenids
        )
        for _, row in ipairs(propRows) do
            propCounts[row.citizenid] = tonumber(row.cnt) or 0
        end

        local vehRows = safeQuery(
            ('SELECT citizenid, COUNT(*) AS cnt FROM player_vehicles WHERE citizenid IN (%s) GROUP BY citizenid'):format(inClause),
            citizenids
        )
        for _, row in ipairs(vehRows) do
            vehCounts[row.citizenid] = tonumber(row.cnt) or 0
        end

        local arrestRows = safeQuery(
            ('SELECT citizenid, COUNT(*) AS cnt FROM mdt_arrests WHERE citizenid IN (%s) GROUP BY citizenid'):format(inClause),
            citizenids
        )
        for _, row in ipairs(arrestRows) do
            arrestCounts[row.citizenid] = tonumber(row.cnt) or 0
        end
    end

    for _, v in ipairs(result) do
        v.id = _
        v.cid = v.citizenid
        v.firstName = v.firstname
        v.lastName = v.lastname
        v.gender = getGender(tonumber(v.gender))
        v.dob = v.dateofbirth
        v.phone = v.phone
        v.image = profilePics[v.citizenid] or nil
        v.occupations = { v.job }
        v.properties = propCounts[v.citizenid] or 0
        v.vehicles = vehCounts[v.citizenid] or 0
        v.arrests = arrestCounts[v.citizenid] or 0
        v.flags = flagsByCid[v.citizenid] or {}
    end

    local endTime = os.clock()
    local elapsedTime = (endTime - startTime) * 1000
    ps.debug(string.format("searchCitizens callback executed in %.2f ms for query: %s", elapsedTime, query))

    if result[1] then
        ps.debug('[searchCitizens] Sample citizen data structure:', result[1])
    end

    return result
end)

-- getCitizenBOLOs - gets active BOLOs by type, probably have a table of active bolos load on script start and use that then save it to db periodically or on resource stop
ps.registerCallback(resourceName .. ':server:getBOLO', function(source, boloType, boloStatus)
    local src = source
    if not CheckAuth(src) then return {} end
    boloType = boloType or 'citizen'
    boloStatus = boloStatus or 'active'
    local BOLOS
    if boloType == 'all' then
        if boloStatus == 'all' then
            BOLOS = MySQL.query.await('SELECT * FROM mdt_bolos ORDER BY id DESC', {})
        else
            BOLOS = MySQL.query.await('SELECT * FROM mdt_bolos WHERE status = ? ORDER BY id DESC', { boloStatus })
        end
    else
        if boloStatus == 'all' then
            BOLOS = MySQL.query.await('SELECT * FROM mdt_bolos WHERE type = ? ORDER BY id DESC', { boloType })
        else
            BOLOS = MySQL.query.await('SELECT * FROM mdt_bolos WHERE type = ? AND status = ? ORDER BY id DESC', { boloType, boloStatus })
        end
    end

    local result = {}
    for k, v in pairs(BOLOS) do
        local formattedBolo = {
            id = v.id,
            reportId = v.reportId and tostring(v.reportId) or 'N/A',
            name = v.subject_name or ps.getPlayerNameByIdentifier(v.subject_id) or 'Unknown',
            type = v.type,
            notes = v.notes or '',
            status = v.status,
        }
        table.insert(result, formattedBolo)
    end
    ps.debug('Fetched ' .. #result .. ' ' .. boloType .. ' BOLOs from database for source ' .. src, result)
    return result
end)

ps.registerCallback(resourceName .. ':server:getCitizenProfile', function(source, citizenid)
    local src = source
    if not CheckAuth(src) then return end

    if not citizenid or citizenid == '' then
        return { success = false, message = 'Missing citizen id' }
    end

    local playerRow = MySQL.single.await([[
        SELECT
            p.citizenid,
            JSON_UNQUOTE(JSON_EXTRACT(p.charinfo, '$.firstname')) AS firstname,
            JSON_UNQUOTE(JSON_EXTRACT(p.charinfo, '$.lastname')) AS lastname,
            JSON_UNQUOTE(JSON_EXTRACT(p.charinfo, '$.gender')) AS gender,
            JSON_UNQUOTE(JSON_EXTRACT(p.charinfo, '$.birthdate')) AS dateofbirth,
            JSON_UNQUOTE(JSON_EXTRACT(p.charinfo, '$.phone')) AS phone,
            p.job,
            p.metadata
        FROM players AS p
        WHERE p.citizenid = ?
        LIMIT 1
    ]], { citizenid })

    if not playerRow then
        return { success = false, message = 'Citizen not found' }
    end

    local profileRow = MySQL.single.await('SELECT id, profilepicture, notes FROM mdt_profiles WHERE citizenid = ?', { citizenid })

    -- Fetch tags and gallery for this profile
    local profileTags = {}
    local profileGallery = {}
    if profileRow and profileRow.id then
        local tagRows = MySQL.query.await('SELECT tag FROM mdt_profiles_tags WHERE profileId = ?', { profileRow.id })
        for _, row in ipairs(tagRows or {}) do
            profileTags[#profileTags + 1] = row.tag
        end
        local galleryRows = MySQL.query.await('SELECT image, label, datecreated FROM mdt_profiles_gallery WHERE profileId = ? ORDER BY datecreated DESC', { profileRow.id })
        for _, row in ipairs(galleryRows or {}) do
            profileGallery[#profileGallery + 1] = { image = row.image, label = row.label, datecreated = row.datecreated }
        end
    end
    local occupations = {}
    if playerRow and playerRow.job then
        local ok, decoded = pcall(json.decode, playerRow.job)
        if ok and decoded then
            if decoded.label then
                occupations[#occupations + 1] = decoded.label
            elseif decoded.name then
                occupations[#occupations + 1] = decoded.name
            end
        end
    end
    local flags = collectCitizenFlags({ citizenid })
    local vehicles = MySQL.query.await('SELECT plate, vehicle FROM player_vehicles WHERE citizenid = ?', { citizenid }) or {}
    local vehiclesCount = #vehicles
    local properties = MySQL.query.await('SELECT house FROM player_houses WHERE citizenid = ?', { citizenid }) or {}
    local propertiesCount = #properties
    local arrestsCount = MySQL.scalar.await('SELECT COUNT(*) FROM mdt_arrests WHERE citizenid = ?', { citizenid }) or 0
    local activeWarrants = MySQL.query.await([[
        SELECT reportid, expirydate
        FROM mdt_reports_warrants
        WHERE citizenid = ? AND expirydate >= NOW()
        ORDER BY expirydate ASC
    ]], { citizenid }) or {}
    local activeBolos = MySQL.query.await([[
        SELECT id, reportId, type, notes
        FROM mdt_bolos
        WHERE status = ? AND subject_id = ?
        ORDER BY id DESC
    ]], { 'active', citizenid }) or {}
    local activeBoloDetails = {}
    for _, bolo in ipairs(activeBolos) do
        activeBoloDetails[#activeBoloDetails + 1] = {
            id = bolo.id,
            reportId = bolo.reportId and tostring(bolo.reportId) or 'N/A',
            type = bolo.type,
            notes = bolo.notes or ''
        }
    end

    local involvedReportIds = {}
    local reportIdSet = {}
    local involvedReports = MySQL.query.await([[
        SELECT reportid
        FROM mdt_reports_involved
        WHERE citizenid = ?
    ]], { citizenid }) or {}
    for _, row in ipairs(involvedReports) do
        local reportId = tonumber(row.reportid)
        if reportId and not reportIdSet[reportId] then
            reportIdSet[reportId] = true
            involvedReportIds[#involvedReportIds + 1] = reportId
        end
    end
    local chargedReports = MySQL.query.await([[
        SELECT reportid
        FROM mdt_reports_charges
        WHERE citizenid = ?
    ]], { citizenid }) or {}
    for _, row in ipairs(chargedReports) do
        local reportId = tonumber(row.reportid)
        if reportId and not reportIdSet[reportId] then
            reportIdSet[reportId] = true
            involvedReportIds[#involvedReportIds + 1] = reportId
        end
    end

    local caseIds = {}
    local caseIdSet = {}
    if #involvedReportIds > 0 then
        local placeholders = (string.rep('?,', #involvedReportIds)):sub(1, -2)
        local caseRows = MySQL.query.await(
            ('SELECT case_id FROM mdt_case_reports WHERE report_id IN (%s)'):format(placeholders),
            involvedReportIds
        ) or {}
        for _, row in ipairs(caseRows) do
            local caseId = tonumber(row.case_id)
            if caseId and not caseIdSet[caseId] then
                caseIdSet[caseId] = true
                caseIds[#caseIds + 1] = caseId
            end
        end
    end

    local evidence = {}
    if #involvedReportIds > 0 or #caseIds > 0 then
        local clauses = {}
        local params = {}
        if #involvedReportIds > 0 then
            clauses[#clauses + 1] = ('report_id IN (%s)'):format((string.rep('?,', #involvedReportIds)):sub(1, -2))
            for _, value in ipairs(involvedReportIds) do
                params[#params + 1] = value
            end
        end
        if #caseIds > 0 then
            clauses[#clauses + 1] = ('case_id IN (%s)'):format((string.rep('?,', #caseIds)):sub(1, -2))
            for _, value in ipairs(caseIds) do
                params[#params + 1] = value
            end
        end
        local evidenceQuery = 'SELECT id, case_id, report_id, title, type, serial, notes, location, created_at FROM mdt_evidence_items WHERE ' .. table.concat(clauses, ' OR ') .. ' ORDER BY created_at DESC'
        evidence = MySQL.query.await(evidenceQuery, params) or {}
    end

    local weapons = MySQL.query.await([[
        SELECT id, serial, scratched, owner, information, weaponClass, weaponModel
        FROM mdt_weapons
        WHERE owner = ?
        ORDER BY id DESC
    ]], { citizenid }) or {}

    local linkedReports = {}
    if #involvedReportIds > 0 then
        local placeholders = (string.rep('?,', #involvedReportIds)):sub(1, -2)
        linkedReports = MySQL.query.await(
            ('SELECT id, title, type, datecreated FROM mdt_reports WHERE id IN (%s) ORDER BY datecreated DESC'):format(placeholders),
            involvedReportIds
        ) or {}
    end
    local licences = {}
    local fingerprint = nil
    local dna = nil
    local metadata = nil
    if playerRow and playerRow.metadata then
        local ok, decoded = pcall(json.decode, playerRow.metadata)
        if ok and decoded then
            metadata = decoded
            if decoded.licences then
                licences = decoded.licences
            end
            if decoded.fingerprint then
                fingerprint = decoded.fingerprint
            end
            if decoded.dna then
                dna = decoded.dna
            end
        end
    end

    -- Auto-fill fingerprint if configured and not already set
    if Config.FingerprintAutoFilled and not fingerprint then
        metadata = metadata or {}
        local chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
        local function randomChar()
            local idx = math.random(1, #chars)
            return chars:sub(idx, idx)
        end
        fingerprint = randomChar() .. randomChar() .. '-'
            .. randomChar() .. randomChar() .. randomChar() .. randomChar() .. '-'
            .. randomChar() .. randomChar() .. randomChar() .. randomChar()
        metadata.fingerprint = fingerprint
        MySQL.update.await('UPDATE players SET metadata = ? WHERE citizenid = ?', { json.encode(metadata), citizenid })
    end

    return {
        success = true,
        profile = {
            citizenid = citizenid,
            firstName = playerRow.firstname or 'Unknown',
            lastName = playerRow.lastname or 'Unknown',
            gender = getGender(tonumber(playerRow.gender)),
            dob = playerRow.dateofbirth or 'N/A',
            phone = playerRow.phone or 'N/A',
            fingerprint = fingerprint,
            dna = dna,
            occupations = occupations,
            properties = propertiesCount,
            vehicles = vehiclesCount,
            arrests = arrestsCount,
            flags = flags[citizenid] or {},
            image = (profileRow and profileRow.profilepicture and profileRow.profilepicture ~= '') and profileRow.profilepicture or nil,
            notes = profileRow and profileRow.notes or '',
            tags = profileTags,
            gallery = profileGallery,
            activeWarrants = activeWarrants,
            activeBolos = activeBoloDetails,
            evidence = evidence,
            weapons = weapons,
            linkedReports = linkedReports,
            ownedVehicles = vehicles,
            propertiesList = properties,
            licenses = {
                driver = licences.driver or false,
                weapon = licences.weapon or false,
            },
            customLicenses = (function()
                local customRows = MySQL.query.await([[
                    SELECT cl.id, cl.name, cl.description,
                           COALESCE(cil.active, 0) as active
                    FROM mdt_custom_licenses cl
                    LEFT JOIN mdt_citizen_licenses cil ON cil.license_id = cl.id AND cil.citizenid = ?
                    ORDER BY cl.id ASC
                ]], { citizenid })
                local result = {}
                for _, r in ipairs(customRows or {}) do
                    result[#result + 1] = {
                        id = r.id,
                        name = r.name,
                        description = r.description or '',
                        active = (tonumber(r.active) or 0) == 1,
                    }
                end
                return result
            end)(),
        }
    }
end)

ps.registerCallback(resourceName .. ':server:updateCitizenLicense', function(source, payload)
    local src = source
    if not CheckAuth(src) then return { success = false, message = 'Unauthorized' } end

    payload = payload or {}
    local citizenId = payload.citizenid
    local licenseType = payload.license
    local enabled = payload.enabled == true
    if not citizenId or not licenseType then
        return { success = false, message = 'Missing citizen id or license' }
    end

    local row = MySQL.single.await('SELECT metadata FROM players WHERE citizenid = ? LIMIT 1', { citizenId })
    if not row then
        return { success = false, message = 'Citizen not found' }
    end

    local metadata = row.metadata and json.decode(row.metadata) or {}
    metadata.licences = metadata.licences or {}
    metadata.licences[licenseType] = enabled

    MySQL.update.await('UPDATE players SET metadata = ? WHERE citizenid = ?', { json.encode(metadata), citizenId })
    return { success = true }
end)

ps.registerCallback(resourceName .. ':server:updateCitizenCustomLicense', function(source, payload)
    local src = source
    if not CheckAuth(src) then return { success = false, message = 'Unauthorized' } end

    payload = payload or {}
    local citizenId = payload.citizenid
    local licenseId = tonumber(payload.licenseId)
    local enabled = payload.enabled == true

    if not citizenId or not licenseId then
        return { success = false, message = 'Missing citizen id or license id' }
    end

    -- Verify the license exists
    local licenseExists = MySQL.scalar.await('SELECT id FROM mdt_custom_licenses WHERE id = ?', { licenseId })
    if not licenseExists then
        return { success = false, message = 'License not found' }
    end

    local grantedBy = ps.getIdentifier(src)

    MySQL.query.await([[
        INSERT INTO mdt_citizen_licenses (citizenid, license_id, active, granted_by)
        VALUES (?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE active = VALUES(active), granted_by = VALUES(granted_by)
    ]], { citizenId, licenseId, enabled and 1 or 0, grantedBy })

    return { success = true }
end)

-- Trigger fingerprint scan on a suspect (opens qb-policejob fingerprint UI)
ps.registerCallback(resourceName .. ':server:addSuspectFingerprint', function(source, citizenid)
    local src = source
    if not CheckAuth(src) then return { success = false, message = 'Unauthorized' } end

    if not citizenid or citizenid == '' then
        return { success = false, message = 'Missing citizen id' }
    end

    -- Check if suspect already has a fingerprint on file
    local row = MySQL.single.await('SELECT metadata FROM players WHERE citizenid = ? LIMIT 1', { citizenid })
    if row then
        local metadata = row.metadata and json.decode(row.metadata) or {}
        if metadata.fingerprint and metadata.fingerprint ~= '' then
            return { success = true, fingerprint = metadata.fingerprint }
        end
    end

    -- Find the suspect's server source (they must be online)
    local targetPlayer = ps.getPlayerByIdentifier(citizenid)
    if not targetPlayer then
        return { success = false, message = 'Suspect is not online' }
    end

    local targetSource = targetPlayer.source or (targetPlayer.PlayerData and targetPlayer.PlayerData.source)
    if not targetSource then
        return { success = false, message = 'Could not find suspect' }
    end

    -- Trigger the fingerprint scan UI on both officer and suspect
    local scanConfig = Config.FingerprintScan
    if not scanConfig or not scanConfig.enabled then
        return { success = false, message = 'Fingerprint scanning is not configured' }
    end

    TriggerClientEvent(scanConfig.suspectEvent, targetSource, src)
    TriggerClientEvent(scanConfig.officerEvent, src, targetSource)

    return { success = true, message = 'Fingerprint scan initiated' }
end)

-- Update citizen fingerprint
ps.registerCallback(resourceName .. ':server:updateCitizenFingerprint', function(source, citizenid, fingerprint)
    local src = source
    if not CheckAuth(src) then return { success = false, message = 'Unauthorized' } end

    if not citizenid or citizenid == '' then
        return { success = false, message = 'Missing citizen id' }
    end

    local row = MySQL.single.await('SELECT metadata FROM players WHERE citizenid = ? LIMIT 1', { citizenid })
    if not row then
        return { success = false, message = 'Citizen not found' }
    end

    local metadata = row.metadata and json.decode(row.metadata) or {}
    metadata.fingerprint = fingerprint or ''
    MySQL.update.await('UPDATE players SET metadata = ? WHERE citizenid = ?', { json.encode(metadata), citizenid })

    if ps.auditLog then
        ps.auditLog(src, 'update_fingerprint', 'citizens', citizenid, { fingerprint = fingerprint })
    end

    return { success = true }
end)

-- Update citizen DNA
ps.registerCallback(resourceName .. ':server:updateCitizenDNA', function(source, citizenid, dna)
    local src = source
    if not CheckAuth(src) then return { success = false, message = 'Unauthorized' } end

    if not citizenid or citizenid == '' then
        return { success = false, message = 'Missing citizen id' }
    end

    local row = MySQL.single.await('SELECT metadata FROM players WHERE citizenid = ? LIMIT 1', { citizenid })
    if not row then
        return { success = false, message = 'Citizen not found' }
    end

    local metadata = row.metadata and json.decode(row.metadata) or {}
    metadata.dna = dna or ''
    MySQL.update.await('UPDATE players SET metadata = ? WHERE citizenid = ?', { json.encode(metadata), citizenid })

    if ps.auditLog then
        ps.auditLog(src, 'update_dna', 'citizens', citizenid, { dna = dna })
    end

    return { success = true }
end)

ps.registerCallback(resourceName .. ':server:createBolo', function(source, payload)
    local src = source
    if not CheckAuth(src) then return { success = false, message = 'Unauthorized' } end

    payload = payload or {}
    local boloType = payload.type or 'citizen'
	local subjectId = payload.subjectId
	local subjectName = payload.subjectName
    local reportId = payload.reportId
    local notes = payload.notes

	if not subjectName or subjectName == '' then
		return { success = false, message = 'Missing required fields' }
	end

    local allowedTypes = { citizen = true, vehicle = true, weapon = true, property = true, other = true }
    if not allowedTypes[boloType] then
        boloType = 'citizen'
    end

	local reportValue = reportId and tonumber(reportId) or nil
	local subjectValue = subjectId and tostring(subjectId) or ''

	-- Prevent duplicate: one active BOLO per subject per report
	if reportValue and subjectValue ~= '' then
		local existing = MySQL.single.await([[
			SELECT id FROM mdt_bolos
			WHERE type = ? AND subject_id = ? AND reportId = ? AND status = 'active'
			LIMIT 1
		]], { boloType, subjectValue, reportValue })
		if existing then
			return { success = false, message = 'An active BOLO already exists.' }
		end
	end

	local inserted = MySQL.insert.await([[
		INSERT INTO mdt_bolos (type, subject_id, subject_name, reportId, notes, status)
		VALUES (?, ?, ?, ?, ?, 'active')
	]], {
		boloType,
		subjectValue,
		subjectName,
		reportValue,
		notes or '',
	})

    if not inserted then
        return { success = false, message = 'Failed to create BOLO' }
    end

    return { success = true, id = inserted }
end)

-- Delete a BOLO
ps.registerCallback(resourceName .. ':server:deleteBolo', function(source, payload)
    local src = source
    if not CheckAuth(src) then return { success = false, message = 'Unauthorized' } end

    payload = payload or {}
    local id = tonumber(payload.id)
    if not id then
        return { success = false, message = 'Invalid BOLO ID' }
    end

    MySQL.query.await('DELETE FROM mdt_bolos WHERE id = ?', { id })
    return { success = true }
end)

-- Update BOLO status (resolve, deactivate, reactivate)
ps.registerCallback(resourceName .. ':server:updateBoloStatus', function(source, payload)
    local src = source
    if not CheckAuth(src) then return { success = false, message = 'Unauthorized' } end

    payload = payload or {}
    local id = tonumber(payload.id)
    local status = payload.status
    if not id or not status then
        return { success = false, message = 'Missing BOLO ID or status' }
    end

    local allowedStatuses = { active = true, inactive = true, resolved = true }
    if not allowedStatuses[status] then
        return { success = false, message = 'Invalid status' }
    end

    MySQL.update.await('UPDATE mdt_bolos SET status = ? WHERE id = ?', { status, id })
    return { success = true }
end)

-- Save citizen profile notes and profile picture
ps.registerCallback(resourceName .. ':server:updateCitizen', function(source, payload)
    local src = source
    if not CheckAuth(src) then return { success = false, message = 'Unauthorized' } end

    payload = payload or {}
    local citizenId = payload.citizenid
    if not citizenId or citizenId == '' then
        return { success = false, message = 'Missing citizen id' }
    end

    EnsureProfileExists(citizenId)

    if payload.notes ~= nil then
        MySQL.update.await('UPDATE mdt_profiles SET notes = ? WHERE citizenid = ?', { payload.notes, citizenId })
    end
    if payload.profilepicture ~= nil then
        MySQL.update.await('UPDATE mdt_profiles SET profilepicture = ? WHERE citizenid = ?', { payload.profilepicture, citizenId })
    end

    return { success = true }
end)

-- Add a tag to a citizen profile
ps.registerCallback(resourceName .. ':server:addCitizenTag', function(source, payload)
    local src = source
    if not CheckAuth(src) then return { success = false, message = 'Unauthorized' } end

    payload = payload or {}
    local citizenId = payload.citizenid
    local tag = payload.tag
    if not citizenId or not tag or tag == '' then
        return { success = false, message = 'Missing citizen id or tag' }
    end

    local profile = MySQL.single.await('SELECT id FROM mdt_profiles WHERE citizenid = ?', { citizenId })
    if not profile then
        return { success = false, message = 'Profile not found' }
    end

    -- Check for duplicate
    local existing = MySQL.scalar.await('SELECT COUNT(*) FROM mdt_profiles_tags WHERE profileId = ? AND tag = ?', { profile.id, tag })
    if existing and existing > 0 then
        return { success = false, message = 'Tag already exists' }
    end

    MySQL.insert.await('INSERT INTO mdt_profiles_tags (profileId, tag) VALUES (?, ?)', { profile.id, tag })
    return { success = true }
end)

-- Remove a tag from a citizen profile
ps.registerCallback(resourceName .. ':server:removeCitizenTag', function(source, payload)
    local src = source
    if not CheckAuth(src) then return { success = false, message = 'Unauthorized' } end

    payload = payload or {}
    local citizenId = payload.citizenid
    local tag = payload.tag
    if not citizenId or not tag then
        return { success = false, message = 'Missing citizen id or tag' }
    end

    local profile = MySQL.single.await('SELECT id FROM mdt_profiles WHERE citizenid = ?', { citizenId })
    if not profile then
        return { success = false, message = 'Profile not found' }
    end

    MySQL.query.await('DELETE FROM mdt_profiles_tags WHERE profileId = ? AND tag = ?', { profile.id, tag })
    return { success = true }
end)

-- Add an image to a citizen profile gallery
ps.registerCallback(resourceName .. ':server:addCitizenGallery', function(source, payload)
    local src = source
    if not CheckAuth(src) then return { success = false, message = 'Unauthorized' } end

    payload = payload or {}
    local citizenId = payload.citizenid
    local image = payload.image
    local label = payload.label or ''
    if not citizenId or not image or image == '' then
        return { success = false, message = 'Missing citizen id or image URL' }
    end

    local profile = MySQL.single.await('SELECT id FROM mdt_profiles WHERE citizenid = ?', { citizenId })
    if not profile then
        return { success = false, message = 'Profile not found' }
    end

    MySQL.insert.await('INSERT INTO mdt_profiles_gallery (profileId, image, label) VALUES (?, ?, ?)', { profile.id, image, label })
    return { success = true }
end)

-- Remove an image from a citizen profile gallery
ps.registerCallback(resourceName .. ':server:removeCitizenGallery', function(source, payload)
    local src = source
    if not CheckAuth(src) then return { success = false, message = 'Unauthorized' } end

    payload = payload or {}
    local citizenId = payload.citizenid
    local image = payload.image
    if not citizenId or not image then
        return { success = false, message = 'Missing citizen id or image' }
    end

    local profile = MySQL.single.await('SELECT id FROM mdt_profiles WHERE citizenid = ?', { citizenId })
    if not profile then
        return { success = false, message = 'Profile not found' }
    end

    MySQL.query.await('DELETE FROM mdt_profiles_gallery WHERE profileId = ? AND image = ?', { profile.id, image })
    return { success = true }
end)

-- Civilian self-profile: returns own profile without LEO auth check
ps.registerCallback(resourceName .. ':server:getMyProfile', function(source)
    local src = source
    local citizenid = ps.getIdentifier(src)
    if not citizenid or citizenid == '' then
        return { success = false, message = 'Could not identify player' }
    end

    -- Run all queries in parallel using promises
    local pOk, pPlayer = pcall(MySQL.single.await, [[
        SELECT p.citizenid,
            JSON_UNQUOTE(JSON_EXTRACT(p.charinfo, '$.firstname')) AS firstname,
            JSON_UNQUOTE(JSON_EXTRACT(p.charinfo, '$.lastname')) AS lastname,
            JSON_UNQUOTE(JSON_EXTRACT(p.charinfo, '$.gender')) AS gender,
            JSON_UNQUOTE(JSON_EXTRACT(p.charinfo, '$.birthdate')) AS dateofbirth,
            JSON_UNQUOTE(JSON_EXTRACT(p.charinfo, '$.phone')) AS phone,
            p.metadata,
            (SELECT COUNT(*) FROM mdt_reports_charges WHERE citizenid COLLATE utf8mb4_general_ci = p.citizenid) AS arrests,
            (SELECT COUNT(*) FROM player_vehicles WHERE citizenid COLLATE utf8mb4_general_ci = p.citizenid) AS vehicle_count
        FROM players p WHERE p.citizenid = ? LIMIT 1
    ]], { citizenid })

    if not pOk or not pPlayer then
        return { success = false, message = 'Profile not found' }
    end

    local fingerprint, dna = nil, nil
    local licences = {}
    if pPlayer.metadata then
        local ok, decoded = pcall(json.decode, pPlayer.metadata)
        if ok and decoded then
            if decoded.fingerprint then fingerprint = decoded.fingerprint end
            if decoded.dna then dna = decoded.dna end
            if decoded.licences then licences = decoded.licences end
        end
    end

    -- Profile picture from mdt_profiles
    local prOk, profileRow = pcall(MySQL.single.await,
        'SELECT profilepicture, notes FROM mdt_profiles WHERE citizenid COLLATE utf8mb4_general_ci = ? LIMIT 1',
        { citizenid })
    profileRow = prOk and profileRow or nil
    local image = (profileRow and profileRow.profilepicture and profileRow.profilepicture ~= '') and profileRow.profilepicture or nil

    local civConfig = Config.CivilianAccess or {}

    -- Warrants (only if config allows)
    local activeWarrants = {}
    if civConfig.showWarrants ~= false then
        local wOk, wResult = pcall(MySQL.query.await,
            'SELECT reportid, expirydate FROM mdt_reports_warrants WHERE citizenid COLLATE utf8mb4_general_ci = ? AND expirydate >= NOW() ORDER BY expirydate ASC',
            { citizenid })
        activeWarrants = wOk and wResult or {}
    end

    -- BOLOs (only if config allows)
    local activeBolos = {}
    if civConfig.showBolos ~= false then
        local bOk, bResult = pcall(MySQL.query.await,
            'SELECT id, reportId, type, notes FROM mdt_bolos WHERE status = ? AND subject_id COLLATE utf8mb4_general_ci = ? ORDER BY id DESC',
            { 'active', citizenid })
        activeBolos = bOk and bResult or {}
    end
    local boloDetails = {}
    for _, bolo in ipairs(activeBolos) do
        boloDetails[#boloDetails + 1] = {
            id = bolo.id,
            reportId = bolo.reportId and tostring(bolo.reportId) or 'N/A',
            type = bolo.type,
            notes = bolo.notes or ''
        }
    end

    -- Linked reports (from both involved and charges tables, same as officer profile)
    local reportIdSet = {}
    local linkedReports = {}

    local riOk, involvedReports = pcall(MySQL.query.await,
        'SELECT reportid FROM mdt_reports_involved WHERE citizenid COLLATE utf8mb4_general_ci = ?',
        { citizenid })
    for _, row in ipairs(riOk and involvedReports or {}) do
        local rid = tonumber(row.reportid)
        if rid and not reportIdSet[rid] then reportIdSet[rid] = true end
    end

    local rcOk, chargedReports = pcall(MySQL.query.await,
        'SELECT reportid FROM mdt_reports_charges WHERE citizenid COLLATE utf8mb4_general_ci = ?',
        { citizenid })
    for _, row in ipairs(rcOk and chargedReports or {}) do
        local rid = tonumber(row.reportid)
        if rid and not reportIdSet[rid] then reportIdSet[rid] = true end
    end

    for rid, _ in pairs(reportIdSet) do
        local rOk, report = pcall(MySQL.single.await, 'SELECT id, title, type FROM mdt_reports WHERE id = ?', { rid })
        if rOk and report then
            linkedReports[#linkedReports + 1] = { id = report.id, title = report.title, type = report.type }
        end
    end

    -- Vehicles
    local vOk, vehicles = pcall(MySQL.query.await,
        'SELECT plate, vehicle FROM player_vehicles WHERE citizenid COLLATE utf8mb4_general_ci = ?',
        { citizenid })
    vehicles = vOk and vehicles or {}

    -- Weapons
    local wpOk, weapons = pcall(MySQL.query.await,
        'SELECT id, serial, scratched, weaponModel FROM mdt_weapons WHERE owner COLLATE utf8mb4_general_ci = ?',
        { citizenid })
    weapons = wpOk and weapons or {}

    -- Custom licenses
    local clOk, customLicenses = pcall(MySQL.query.await,
        'SELECT cl.id, cl.name, cl.description, COALESCE(cil.active, 0) as active FROM mdt_custom_licenses cl LEFT JOIN mdt_citizen_licenses cil ON cil.license_id = cl.id AND cil.citizenid COLLATE utf8mb4_general_ci = ? ORDER BY cl.id ASC',
        { citizenid })
    customLicenses = clOk and customLicenses or {}

    local clList = {}
    for _, r in ipairs(customLicenses) do
        clList[#clList + 1] = { id = r.id, name = r.name, description = r.description or '', active = (tonumber(r.active) or 0) == 1 }
    end

    return {
        success = true,
        profile = {
            citizenid = citizenid,
            firstName = pPlayer.firstname or 'Unknown',
            lastName = pPlayer.lastname or 'Unknown',
            gender = getGender(tonumber(pPlayer.gender)),
            dob = pPlayer.dateofbirth or 'N/A',
            phone = pPlayer.phone or 'N/A',
            fingerprint = fingerprint,
            dna = dna,
            image = image,
            arrests = pPlayer.arrests or 0,
            activeWarrants = activeWarrants,
            activeBolos = boloDetails,
            linkedReports = linkedReports,
            ownedVehicles = vehicles,
            weapons = weapons,
            licenses = { driver = licences.driver or false, weapon = licences.weapon or false },
            customLicenses = clList,
        }
    }
end)
