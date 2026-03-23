local resourceName = tostring(GetCurrentResourceName())

local function buildPPRNumber(id)
    local year = os.date('%Y')
    return ('PPR-%s-%05d'):format(year, id)
end

-- Get paginated list of PPR entries
ps.registerCallback(resourceName .. ':server:getPPRList', function(source, pageNum, filters)
    local src = source
    if not CheckAuth(src) then return { entries = {}, hasMore = false } end

    filters = filters or {}
    local citizenId = ps.getIdentifier(src)
    local hasPPRView = CheckPermission(src, 'ppr_view')

    local page = tonumber(pageNum) or 1
    local limit = Config.Pagination and Config.Pagination.Cases or 20
    local offset = (page - 1) * limit

    local clauses = {}
    local values = {}

    -- If no ppr_view permission, only show own records
    if not hasPPRView then
        clauses[#clauses + 1] = 'officer_citizenid = ?'
        values[#values + 1] = citizenId
    end

    if filters.category and filters.category ~= '' then
        clauses[#clauses + 1] = 'category = ?'
        values[#values + 1] = filters.category
    end

    if filters.search and filters.search ~= '' then
        clauses[#clauses + 1] = '(officer_name LIKE ? OR author_name LIKE ? OR ppr_number LIKE ? OR title LIKE ?)'
        local term = '%' .. filters.search .. '%'
        values[#values + 1] = term
        values[#values + 1] = term
        values[#values + 1] = term
        values[#values + 1] = term
    end

    local whereClause = ''
    if #clauses > 0 then
        whereClause = 'WHERE ' .. table.concat(clauses, ' AND ')
    end

    values[#values + 1] = limit
    values[#values + 1] = offset

    local query = ([[
        SELECT id, ppr_number, officer_name, officer_citizenid, author_name, category, title, incident_date, created_at
        FROM mdt_ppr
        %s
        ORDER BY created_at DESC
        LIMIT ? OFFSET ?
    ]]):format(whereClause)

    local ok, rows = pcall(MySQL.query.await, query, values)
    if not ok then
        ps.warn('[getPPRList] Query failed: ' .. tostring(rows))
        return { entries = {}, hasMore = false }
    end

    return {
        entries = rows or {},
        hasMore = rows and #rows >= limit or false
    }
end)

-- Get single PPR entry with notes
ps.registerCallback(resourceName .. ':server:getPPR', function(source, data)
    local src = source
    if not CheckAuth(src) then return { success = false, error = 'Unauthorized' } end

    local pprId = tonumber(data)
    if not pprId then return { success = false, error = 'Invalid PPR id' } end

    local entry = MySQL.single.await('SELECT * FROM mdt_ppr WHERE id = ?', { pprId })
    if not entry then return { success = false, error = 'PPR not found' } end

    -- Permission check: ppr_view OR own record
    local citizenId = ps.getIdentifier(src)
    local hasPPRView = CheckPermission(src, 'ppr_view')
    if not hasPPRView and entry.officer_citizenid ~= citizenId then
        return { success = false, error = 'Unauthorized' }
    end

    local nOk, notes = pcall(MySQL.query.await, [[
        SELECT id, ppr_id, content, author_citizenid, author_name, created_at
        FROM mdt_ppr_notes
        WHERE ppr_id = ?
        ORDER BY created_at DESC
    ]], { pprId })

    return {
        success = true,
        data = {
            entry = entry,
            notes = (nOk and notes) or {}
        }
    }
end)

-- Get PPR history for a specific officer
ps.registerCallback(resourceName .. ':server:getOfficerPPRHistory', function(source, officerCitizenId)
    local src = source
    if not CheckAuth(src) then return {} end

    if not officerCitizenId or officerCitizenId == '' then return {} end

    -- Permission check: ppr_view OR own record
    local citizenId = ps.getIdentifier(src)
    local hasPPRView = CheckPermission(src, 'ppr_view')
    if not hasPPRView and officerCitizenId ~= citizenId then
        return {}
    end

    local ok, rows = pcall(MySQL.query.await, [[
        SELECT id, ppr_number, category, title, author_name, incident_date, created_at
        FROM mdt_ppr
        WHERE officer_citizenid = ?
        ORDER BY created_at DESC
        LIMIT 50
    ]], { officerCitizenId })

    if not ok then return {} end
    return rows or {}
end)

-- Create a new PPR entry
ps.registerCallback(resourceName .. ':server:createPPR', function(source, data)
    local src = source
    if not CheckAuth(src) then return { success = false, error = 'Unauthorized' } end
    if not CheckPermission(src, 'ppr_manage') then
        return { success = false, error = 'No permission to create PPR entries' }
    end

    data = data or {}

    local citizenId = ps.getIdentifier(src)
    local profile = MySQL.single.await('SELECT fullname FROM mdt_profiles WHERE citizenid = ?', { citizenId })
    local authorName = profile and profile.fullname or 'Unknown'

    local officerCitizenId = data.officer_citizenid or ''
    local officerName = data.officer_name or ''

    if officerCitizenId == '' or officerName == '' then
        return { success = false, error = 'Officer is required' }
    end

    local pprId = MySQL.insert.await([[
        INSERT INTO mdt_ppr
        (ppr_number, officer_citizenid, officer_name, author_citizenid, author_name,
         category, title, description, incident_date, incident_location, linked_report_id, linked_case_id)
        VALUES ('', ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ]], {
        officerCitizenId,
        officerName,
        citizenId,
        authorName,
        data.category or 'coaching',
        data.title or '',
        data.description or '',
        data.incident_date or nil,
        data.incident_location or nil,
        tonumber(data.linked_report_id) or nil,
        tonumber(data.linked_case_id) or nil
    })

    if not pprId then
        return { success = false, error = 'Failed to create PPR entry' }
    end
    local pprNumber = buildPPRNumber(pprId)
    MySQL.update.await('UPDATE mdt_ppr SET ppr_number = ? WHERE id = ?', { pprNumber, pprId })

    return { success = true, pprNumber = pprNumber, id = pprId }
end)

-- Update a PPR entry
ps.registerCallback(resourceName .. ':server:updatePPR', function(source, pprId, updates)
    local src = source
    if not CheckAuth(src) then return { success = false, error = 'Unauthorized' } end
    if not CheckPermission(src, 'ppr_manage') then
        return { success = false, error = 'No permission to edit PPR entries' }
    end

    pprId = tonumber(pprId)
    updates = updates or {}
    if not pprId then return { success = false, error = 'Invalid PPR id' } end

    local sets = {}
    local vals = {}

    local allowedFields = { 'title', 'description', 'category', 'incident_date', 'incident_location', 'linked_report_id', 'linked_case_id' }
    for _, field in ipairs(allowedFields) do
        if updates[field] ~= nil then
            sets[#sets + 1] = field .. ' = ?'
            vals[#vals + 1] = updates[field]
        end
    end

    if #sets == 0 then
        return { success = false, error = 'No fields to update' }
    end

    vals[#vals + 1] = pprId
    MySQL.update.await('UPDATE mdt_ppr SET ' .. table.concat(sets, ', ') .. ' WHERE id = ?', vals)
    return { success = true }
end)

-- Delete a PPR entry
ps.registerCallback(resourceName .. ':server:deletePPR', function(source, pprId)
    local src = source
    if not CheckAuth(src) then return { success = false, error = 'Unauthorized' } end
    if not CheckPermission(src, 'ppr_manage') then
        return { success = false, error = 'No permission to delete PPR entries' }
    end

    pprId = tonumber(pprId)
    if not pprId then return { success = false, error = 'Invalid PPR id' } end

    MySQL.query.await('DELETE FROM mdt_ppr WHERE id = ?', { pprId })
    return { success = true }
end)

-- Add a note to a PPR entry
ps.registerCallback(resourceName .. ':server:addPPRNote', function(source, pprId, content)
    local src = source
    if not CheckAuth(src) then return { success = false, error = 'Unauthorized' } end
    if not CheckPermission(src, 'ppr_manage') then
        return { success = false, error = 'No permission to add PPR notes' }
    end

    pprId = tonumber(pprId)
    if not pprId or not content or content == '' then
        return { success = false, error = 'Invalid PPR id or empty note' }
    end

    local citizenId = ps.getIdentifier(src)
    local profile = MySQL.single.await('SELECT fullname FROM mdt_profiles WHERE citizenid = ?', { citizenId })
    local authorName = profile and profile.fullname or 'Unknown'

    MySQL.insert.await([[
        INSERT INTO mdt_ppr_notes (ppr_id, content, author_citizenid, author_name)
        VALUES (?, ?, ?, ?)
    ]], { pprId, content, citizenId, authorName })

    return { success = true }
end)

-- Delete a PPR note
ps.registerCallback(resourceName .. ':server:deletePPRNote', function(source, noteId, pprId)
    local src = source
    if not CheckAuth(src) then return { success = false, error = 'Unauthorized' } end
    if not CheckPermission(src, 'ppr_manage') then
        return { success = false, error = 'No permission to delete PPR notes' }
    end

    noteId = tonumber(noteId)
    pprId = tonumber(pprId)
    if not noteId or not pprId then
        return { success = false, error = 'Invalid note or PPR id' }
    end

    MySQL.query.await('DELETE FROM mdt_ppr_notes WHERE id = ? AND ppr_id = ?', { noteId, pprId })
    return { success = true }
end)
