local resourceName = tostring(GetCurrentResourceName())

local function buildComplaintNumber(id)
    local year = os.date('%Y')
    return ('IA-%s-%05d'):format(year, id)
end

-- Submit a complaint (NO CheckAuth -- civilians can submit)
ps.registerCallback(resourceName .. ':server:submitComplaint', function(source, data)
    local src = source
    data = data or {}

    local citizenid = ps.getIdentifier(src)
    if not citizenid then
        return { success = false, error = 'Missing citizen id' }
    end

    local player = MySQL.single.await([[
        SELECT JSON_UNQUOTE(JSON_EXTRACT(charinfo, "$.firstname")) AS firstname,
               JSON_UNQUOTE(JSON_EXTRACT(charinfo, "$.lastname")) AS lastname
        FROM players WHERE citizenid = ?
    ]], { citizenid })

    local complainantName = 'Unknown'
    if player then
        complainantName = (player.firstname or 'Unknown') .. ' ' .. (player.lastname or '')
    end

    local witnesses = data.witnesses
    if type(witnesses) == 'table' then
        witnesses = json.encode(witnesses)
    end

    local evidence = data.evidence
    if type(evidence) == 'table' then
        evidence = json.encode(evidence)
    end

    local officerName = data.officerName or data.officer_name or ''
    local officerBadge = data.officerBadge or data.officer_badge or ''
    local incidentDate = data.incidentDate or data.incident_date or nil
    local incidentLocation = data.incidentLocation or data.incident_location or ''

    local complaintId = MySQL.insert.await([[
        INSERT INTO mdt_ia_complaints
        (complaint_number, complainant_citizenid, complainant_name, complainant_phone, officer_name, officer_badge,
         category, description, incident_date, incident_location, witnesses, evidence, status)
        VALUES ('', ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'open')
    ]], {
        citizenid,
        complainantName,
        data.complainantPhone or data.complainant_phone or nil,
        officerName,
        officerBadge,
        data.category or 'other',
        data.description or '',
        incidentDate,
        incidentLocation,
        witnesses or '[]',
        evidence or '[]'
    })

    if not complaintId then
        return { success = false, error = 'Failed to submit complaint' }
    end

    local complaintNumber = buildComplaintNumber(complaintId)
    MySQL.update.await('UPDATE mdt_ia_complaints SET complaint_number = ? WHERE id = ?', { complaintNumber, complaintId })

    return {
        success = true,
        complaintNumber = complaintNumber
    }
end)

-- Get paginated list of IA complaints
ps.registerCallback(resourceName .. ':server:getIAComplaints', function(source, pageNum, filters)
    local src = source
    filters = filters or {}
    print(('[ps-mdt] getIAComplaints called | page=%s | status=[%s] | search=[%s]'):format(
        tostring(pageNum), tostring(filters.status), tostring(filters.search)))

    if not CheckAuth(src) then
        print('[ps-mdt] getIAComplaints: CheckAuth FAILED for source ' .. tostring(src))
        return { complaints = {}, hasMore = false }
    end

    local page = tonumber(pageNum) or 1
    local limit = Config.Pagination and Config.Pagination.Cases or 20
    local offset = (page - 1) * limit

    local clauses = {}
    local values = {}

    if filters.status and filters.status ~= '' then
        clauses[#clauses + 1] = 'status = ?'
        values[#values + 1] = filters.status
    end

    if filters.search and filters.search ~= '' then
        clauses[#clauses + 1] = '(officer_name LIKE ? OR complainant_name LIKE ? OR complaint_number LIKE ?)'
        local searchTerm = '%' .. filters.search .. '%'
        values[#values + 1] = searchTerm
        values[#values + 1] = searchTerm
        values[#values + 1] = searchTerm
    end

    local whereClause = ''
    if #clauses > 0 then
        whereClause = 'WHERE ' .. table.concat(clauses, ' AND ')
    end

    values[#values + 1] = limit
    values[#values + 1] = offset

    local query = ([[
        SELECT id, complaint_number, complainant_name, officer_name, officer_badge,
               category, status, assigned_to_name, created_at
        FROM mdt_ia_complaints
        %s
        ORDER BY created_at DESC
        LIMIT ? OFFSET ?
    ]]):format(whereClause)

    local ok, rows = pcall(MySQL.query.await, query, values)

    if not ok then
        print('^1[ps-mdt] getIAComplaints QUERY FAILED: ' .. tostring(rows) .. '^0')
        return { complaints = {}, hasMore = false }
    end

    print(('[ps-mdt] getIAComplaints: query OK, returned %d rows | whereClause=[%s]'):format(
        rows and #rows or 0, whereClause))

    -- Debug: dump all rows if empty but table has data
    if rows and #rows == 0 then
        local chk, all = pcall(MySQL.query.await, 'SELECT id, status, complaint_number FROM mdt_ia_complaints LIMIT 10')
        if chk and all then
            print(('[ps-mdt] getIAComplaints: table has %d rows total'):format(#all))
            for _, r in ipairs(all) do
                print(('[ps-mdt]   -> id=%s status=[%s] number=[%s]'):format(tostring(r.id), tostring(r.status), tostring(r.complaint_number)))
            end
        end
    end

    return {
        complaints = rows or {},
        hasMore = rows and #rows >= limit or false
    }
end)

-- Get single IA complaint with notes
ps.registerCallback(resourceName .. ':server:getIAComplaint', function(source, data)
    local src = source
    if not CheckAuth(src) then return { success = false, error = 'Unauthorized' } end

    local complaintId = tonumber(data)
    if not complaintId then
        return { success = false, error = 'Invalid complaint id' }
    end

    local complaint = MySQL.single.await('SELECT * FROM mdt_ia_complaints WHERE id = ?', { complaintId })
    if not complaint then
        return { success = false, error = 'Complaint not found' }
    end

    local nOk, notes = pcall(MySQL.query.await, [[
        SELECT id, complaint_id, content, author_citizenid, author_name, created_at
        FROM mdt_ia_notes
        WHERE complaint_id = ?
        ORDER BY created_at DESC
    ]], { complaintId })

    return {
        success = true,
        data = {
            complaint = complaint,
            notes = (nOk and notes) or {}
        }
    }
end)

-- Get IA complaints against a specific officer (by name match)
ps.registerCallback(resourceName .. ':server:getIAHistoryForOfficer', function(source, officerName)
    local src = source
    if not CheckAuth(src) then return {} end

    if not officerName or officerName == '' then return {} end

    local ok, rows = pcall(MySQL.query.await, [[
        SELECT id, complaint_number, category, status, created_at
        FROM mdt_ia_complaints
        WHERE officer_name LIKE ?
        ORDER BY created_at DESC
        LIMIT 50
    ]], { '%' .. officerName .. '%' })

    if not ok then return {} end
    return rows or {}
end)

-- Update IA complaint details (officer, badge, date, location)
ps.registerCallback(resourceName .. ':server:updateIAComplaintInfo', function(source, complaintId, updates)
    local src = source
    if not CheckAuth(src) then return { success = false, error = 'Unauthorized' } end

    complaintId = tonumber(complaintId)
    updates = updates or {}
    if not complaintId then
        return { success = false, error = 'Invalid complaint id' }
    end

    local sets = {}
    local vals = {}

    if updates.officer_name ~= nil then
        sets[#sets + 1] = 'officer_name = ?'
        vals[#vals + 1] = updates.officer_name
    end
    if updates.officer_badge ~= nil then
        sets[#sets + 1] = 'officer_badge = ?'
        vals[#vals + 1] = updates.officer_badge
    end
    if updates.incident_date ~= nil then
        sets[#sets + 1] = 'incident_date = ?'
        vals[#vals + 1] = updates.incident_date
    end
    if updates.incident_location ~= nil then
        sets[#sets + 1] = 'incident_location = ?'
        vals[#vals + 1] = updates.incident_location
    end

    if #sets == 0 then
        return { success = false, error = 'No fields to update' }
    end

    vals[#vals + 1] = complaintId
    MySQL.update.await('UPDATE mdt_ia_complaints SET ' .. table.concat(sets, ', ') .. ' WHERE id = ?', vals)
    return { success = true }
end)

-- Update IA complaint status
ps.registerCallback(resourceName .. ':server:updateIAStatus', function(source, complaintId, status)
    local src = source
    if not CheckAuth(src) then return { success = false, error = 'Unauthorized' } end

    complaintId = tonumber(complaintId)
    if not complaintId or not status then
        return { success = false, error = 'Invalid complaint id or status' }
    end

    local ok, err = pcall(MySQL.update.await, 'UPDATE mdt_ia_complaints SET status = ? WHERE id = ?', { status, complaintId })
    if not ok then
        ps.warn('[updateIAStatus] Failed: ' .. tostring(err))
        return { success = false, error = 'Failed to update status: ' .. tostring(err) }
    end

    return { success = true }
end)

-- Assign an investigator to an IA complaint (or unassign with '__unassign__')
ps.registerCallback(resourceName .. ':server:assignIAComplaint', function(source, complaintId, assigneeCitizenId)
    local src = source
    if not CheckAuth(src) then return { success = false, error = 'Unauthorized' } end

    complaintId = tonumber(complaintId)
    if not complaintId or not assigneeCitizenId then
        return { success = false, error = 'Invalid complaint or assignee' }
    end

    -- Handle unassign
    if assigneeCitizenId == '__unassign__' then
        MySQL.update.await('UPDATE mdt_ia_complaints SET assigned_to = NULL, assigned_to_name = NULL WHERE id = ?', { complaintId })
        return { success = true }
    end

    local profile = MySQL.single.await('SELECT fullname FROM mdt_profiles WHERE citizenid = ?', { assigneeCitizenId })
    local assigneeName = profile and profile.fullname or 'Unknown'

    MySQL.update.await('UPDATE mdt_ia_complaints SET assigned_to = ?, assigned_to_name = ? WHERE id = ?', {
        assigneeCitizenId,
        assigneeName,
        complaintId
    })

    return { success = true }
end)

-- Add a note to an IA complaint
ps.registerCallback(resourceName .. ':server:addIANote', function(source, complaintId, content)
    local src = source
    if not CheckAuth(src) then return { success = false, error = 'Unauthorized' } end

    complaintId = tonumber(complaintId)
    if not complaintId or not content or content == '' then
        return { success = false, error = 'Invalid complaint or empty note' }
    end

    local citizenId = ps.getIdentifier(src)
    local profile = MySQL.single.await('SELECT fullname FROM mdt_profiles WHERE citizenid = ?', { citizenId })
    local authorName = profile and profile.fullname or 'Unknown'

    MySQL.insert.await([[
        INSERT INTO mdt_ia_notes (complaint_id, content, author_citizenid, author_name)
        VALUES (?, ?, ?, ?)
    ]], { complaintId, content, citizenId, authorName })

    return { success = true }
end)

-- Delete a note from an IA complaint
ps.registerCallback(resourceName .. ':server:deleteIANote', function(source, noteId, complaintId)
    local src = source
    if not CheckAuth(src) then return { success = false, error = 'Unauthorized' } end

    noteId = tonumber(noteId)
    complaintId = tonumber(complaintId)
    if not noteId or not complaintId then
        return { success = false, error = 'Invalid note or complaint' }
    end

    MySQL.query.await('DELETE FROM mdt_ia_notes WHERE id = ? AND complaint_id = ?', { noteId, complaintId })
    return { success = true }
end)
