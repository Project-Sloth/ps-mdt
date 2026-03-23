local resourceName = tostring(GetCurrentResourceName())

local function buildFTONumber(id)
    local year = os.date('%Y')
    return ('FTO-%s-%05d'):format(year, id)
end

-- Get phases for job
ps.registerCallback(resourceName .. ':server:getFTOPhases', function(source)
    local src = source
    if not CheckAuth(src) then return {} end
    local job = ps.getJobName(src) or 'police'
    local ok, rows = pcall(MySQL.query.await, 'SELECT * FROM mdt_fto_phases WHERE job = ? ORDER BY sort_order ASC', { job })
    return (ok and rows) or {}
end)

-- Save phases (replace all for job)
ps.registerCallback(resourceName .. ':server:saveFTOPhases', function(source, phases)
    local src = source
    if not CheckAuth(src) then return { success = false } end
    if not CheckPermission(src, 'fto_manage') then return { success = false, error = 'No permission' } end
    local job = ps.getJobName(src) or 'police'
    phases = phases or {}

    MySQL.query.await('DELETE FROM mdt_fto_phases WHERE job = ?', { job })
    for i, phase in ipairs(phases) do
        MySQL.insert.await('INSERT INTO mdt_fto_phases (job, name, description, duration_days, sort_order) VALUES (?, ?, ?, ?, ?)', {
            job, phase.name or '', phase.description or '', tonumber(phase.duration_days) or 0, i
        })
    end
    return { success = true }
end)

-- Get competencies for job
ps.registerCallback(resourceName .. ':server:getFTOCompetencies', function(source)
    local src = source
    if not CheckAuth(src) then return {} end
    local job = ps.getJobName(src) or 'police'
    local ok, rows = pcall(MySQL.query.await, 'SELECT * FROM mdt_fto_competencies WHERE job = ? ORDER BY sort_order ASC', { job })
    return (ok and rows) or {}
end)

-- Save competencies (replace all for job)
ps.registerCallback(resourceName .. ':server:saveFTOCompetencies', function(source, competencies)
    local src = source
    if not CheckAuth(src) then return { success = false } end
    if not CheckPermission(src, 'fto_manage') then return { success = false, error = 'No permission' } end
    local job = ps.getJobName(src) or 'police'
    competencies = competencies or {}

    MySQL.query.await('DELETE FROM mdt_fto_competencies WHERE job = ?', { job })
    for i, comp in ipairs(competencies) do
        MySQL.insert.await('INSERT INTO mdt_fto_competencies (job, name, category, sort_order) VALUES (?, ?, ?, ?)', {
            job, comp.name or '', comp.category or 'General', i
        })
    end
    return { success = true }
end)

-- Get paginated list of FTO assignments
ps.registerCallback(resourceName .. ':server:getFTOList', function(source, pageNum, filters)
    local src = source
    if not CheckAuth(src) then return { entries = {}, hasMore = false } end

    filters = filters or {}
    local citizenId = ps.getIdentifier(src)
    local hasFTOView = CheckPermission(src, 'fto_view')

    local page = tonumber(pageNum) or 1
    local limit = 20
    local offset = (page - 1) * limit

    local clauses = {}
    local values = {}

    if not hasFTOView then
        clauses[#clauses + 1] = '(a.trainee_citizenid = ? OR a.trainer_citizenid = ?)'
        values[#values + 1] = citizenId
        values[#values + 1] = citizenId
    end

    if filters.status and filters.status ~= '' and filters.status ~= 'all' then
        clauses[#clauses + 1] = 'a.status = ?'
        values[#values + 1] = filters.status
    end

    if filters.search and filters.search ~= '' then
        clauses[#clauses + 1] = '(a.trainee_name LIKE ? OR a.trainer_name LIKE ? OR a.fto_number LIKE ?)'
        local s = '%' .. filters.search .. '%'
        values[#values + 1] = s
        values[#values + 1] = s
        values[#values + 1] = s
    end

    local whereClause = #clauses > 0 and ('WHERE ' .. table.concat(clauses, ' AND ')) or ''
    values[#values + 1] = limit
    values[#values + 1] = offset

    local query = ([[
        SELECT a.*, p.name AS phase_name,
            (SELECT COUNT(*) FROM mdt_fto_dors d WHERE d.assignment_id = a.id) AS dor_count,
            (SELECT d2.overall_rating FROM mdt_fto_dors d2 WHERE d2.assignment_id = a.id ORDER BY d2.created_at DESC LIMIT 1) AS latest_rating
        FROM mdt_fto_assignments a
        LEFT JOIN mdt_fto_phases p ON a.current_phase_id = p.id
        %s
        ORDER BY a.created_at DESC
        LIMIT ? OFFSET ?
    ]]):format(whereClause)

    local ok, rows = pcall(MySQL.query.await, query, values)
    if not ok then return { entries = {}, hasMore = false } end

    return {
        entries = rows or {},
        hasMore = rows and #rows >= limit or false,
    }
end)

-- Get single FTO assignment with DORs
ps.registerCallback(resourceName .. ':server:getFTO', function(source, data)
    local src = source
    if not CheckAuth(src) then return { success = false } end

    local assignmentId = tonumber(data)
    if not assignmentId then return { success = false, error = 'Invalid ID' } end

    local entry = MySQL.single.await([[
        SELECT a.*, p.name AS phase_name
        FROM mdt_fto_assignments a
        LEFT JOIN mdt_fto_phases p ON a.current_phase_id = p.id
        WHERE a.id = ?
    ]], { assignmentId })
    if not entry then return { success = false, error = 'Not found' } end

    local citizenId = ps.getIdentifier(src)
    local hasFTOView = CheckPermission(src, 'fto_view')
    if not hasFTOView and entry.trainee_citizenid ~= citizenId and entry.trainer_citizenid ~= citizenId then
        return { success = false, error = 'Unauthorized' }
    end

    local dOk, dors = pcall(MySQL.query.await, [[
        SELECT d.*, p.name AS phase_name
        FROM mdt_fto_dors d
        LEFT JOIN mdt_fto_phases p ON d.phase_id = p.id
        WHERE d.assignment_id = ?
        ORDER BY d.created_at DESC
    ]], { assignmentId })

    local dorList = (dOk and dors) or {}
    for _, dor in ipairs(dorList) do
        local rOk, ratings = pcall(MySQL.query.await, [[
            SELECT r.*, c.name AS competency_name, c.category AS competency_category
            FROM mdt_fto_dor_ratings r
            LEFT JOIN mdt_fto_competencies c ON r.competency_id = c.id
            WHERE r.dor_id = ?
            ORDER BY c.sort_order ASC
        ]], { dor.id })
        dor.ratings = (rOk and ratings) or {}
    end

    return { success = true, data = { entry = entry, dors = dorList } }
end)

-- Get officer FTO history (for roster panel)
ps.registerCallback(resourceName .. ':server:getOfficerFTOHistory', function(source, officerCitizenId)
    local src = source
    if not CheckAuth(src) then return {} end
    if not officerCitizenId or officerCitizenId == '' then return {} end

    local ok, rows = pcall(MySQL.query.await, [[
        SELECT a.id, a.fto_number, a.status, a.trainer_name, a.trainee_name,
            a.start_date, a.end_date, a.created_at,
            p.name AS phase_name,
            (SELECT COUNT(*) FROM mdt_fto_dors d WHERE d.assignment_id = a.id) AS dor_count,
            (SELECT d2.overall_rating FROM mdt_fto_dors d2 WHERE d2.assignment_id = a.id ORDER BY d2.created_at DESC LIMIT 1) AS latest_rating
        FROM mdt_fto_assignments a
        LEFT JOIN mdt_fto_phases p ON a.current_phase_id = p.id
        WHERE a.trainee_citizenid = ? OR a.trainer_citizenid = ?
        ORDER BY a.created_at DESC
    ]], { officerCitizenId, officerCitizenId })

    return (ok and rows) or {}
end)

-- Create FTO assignment
ps.registerCallback(resourceName .. ':server:createFTOAssignment', function(source, data)
    local src = source
    if not CheckAuth(src) then return { success = false } end
    if not CheckPermission(src, 'fto_manage') then return { success = false, error = 'No permission' } end

    data = data or {}
    if not data.trainee_citizenid or data.trainee_citizenid == '' then
        return { success = false, error = 'Trainee is required' }
    end
    if not data.trainer_citizenid or data.trainer_citizenid == '' then
        return { success = false, error = 'Trainer is required' }
    end

    local assignmentId = MySQL.insert.await([[
        INSERT INTO mdt_fto_assignments
        (fto_number, trainee_citizenid, trainee_name, trainer_citizenid, trainer_name,
         current_phase_id, status, start_date, notes)
        VALUES ('', ?, ?, ?, ?, ?, 'active', ?, ?)
    ]], {
        data.trainee_citizenid, data.trainee_name or '',
        data.trainer_citizenid, data.trainer_name or '',
        tonumber(data.current_phase_id) or nil,
        data.start_date or os.date('%m/%d/%Y'),
        data.notes or nil,
    })

    if not assignmentId then return { success = false, error = 'Failed to create assignment' } end

    local ftoNumber = buildFTONumber(assignmentId)
    MySQL.update.await('UPDATE mdt_fto_assignments SET fto_number = ? WHERE id = ?', { ftoNumber, assignmentId })

    return { success = true, id = assignmentId, fto_number = ftoNumber }
end)

-- Update FTO assignment
ps.registerCallback(resourceName .. ':server:updateFTOAssignment', function(source, assignmentId, updates)
    local src = source
    if not CheckAuth(src) then return { success = false } end
    if not CheckPermission(src, 'fto_manage') then return { success = false, error = 'No permission' } end

    assignmentId = tonumber(assignmentId)
    updates = updates or {}
    if not assignmentId then return { success = false, error = 'Invalid ID' } end

    local sets = {}
    local vals = {}
    local allowed = { 'current_phase_id', 'status', 'end_date', 'notes', 'trainer_citizenid', 'trainer_name' }

    for _, field in ipairs(allowed) do
        if updates[field] ~= nil then
            sets[#sets + 1] = field .. ' = ?'
            vals[#vals + 1] = updates[field]
        end
    end

    if #sets == 0 then return { success = false, error = 'No fields to update' } end

    vals[#vals + 1] = assignmentId
    MySQL.update.await('UPDATE mdt_fto_assignments SET ' .. table.concat(sets, ', ') .. ' WHERE id = ?', vals)
    return { success = true }
end)

-- Delete FTO assignment
ps.registerCallback(resourceName .. ':server:deleteFTOAssignment', function(source, assignmentId)
    local src = source
    if not CheckAuth(src) then return { success = false } end
    if not CheckPermission(src, 'fto_manage') then return { success = false, error = 'No permission' } end

    assignmentId = tonumber(assignmentId)
    if not assignmentId then return { success = false, error = 'Invalid ID' } end

    MySQL.query.await('DELETE FROM mdt_fto_assignments WHERE id = ?', { assignmentId })
    return { success = true }
end)

-- Create DOR (Daily Observation Report)
ps.registerCallback(resourceName .. ':server:createFTODor', function(source, data)
    local src = source
    if not CheckAuth(src) then return { success = false } end
    if not CheckPermission(src, 'fto_manage') then return { success = false, error = 'No permission' } end

    data = data or {}
    local assignmentId = tonumber(data.assignment_id)
    if not assignmentId then return { success = false, error = 'Assignment is required' } end

    local citizenId = ps.getIdentifier(src)
    local profile = MySQL.single.await('SELECT fullname FROM mdt_profiles WHERE citizenid = ?', { citizenId })
    local authorName = profile and profile.fullname or 'Unknown'

    local dorId = MySQL.insert.await([[
        INSERT INTO mdt_fto_dors (assignment_id, phase_id, author_citizenid, author_name, shift_date, overall_rating, notes)
        VALUES (?, ?, ?, ?, ?, ?, ?)
    ]], {
        assignmentId,
        tonumber(data.phase_id) or nil,
        citizenId, authorName,
        data.shift_date or os.date('%m/%d/%Y'),
        tonumber(data.overall_rating) or 3,
        data.notes or nil,
    })

    if not dorId then return { success = false, error = 'Failed to create DOR' } end

    local ratings = data.ratings or {}
    for _, r in ipairs(ratings) do
        local compId = tonumber(r.competency_id)
        local rating = tonumber(r.rating)
        if compId and rating then
            MySQL.insert.await([[
                INSERT INTO mdt_fto_dor_ratings (dor_id, competency_id, rating, notes)
                VALUES (?, ?, ?, ?)
            ]], { dorId, compId, rating, r.notes or nil })
        end
    end

    return { success = true, id = dorId }
end)

-- Delete DOR
ps.registerCallback(resourceName .. ':server:deleteFTODor', function(source, dorId)
    local src = source
    if not CheckAuth(src) then return { success = false } end
    if not CheckPermission(src, 'fto_manage') then return { success = false, error = 'No permission' } end

    dorId = tonumber(dorId)
    if not dorId then return { success = false, error = 'Invalid ID' } end

    MySQL.query.await('DELETE FROM mdt_fto_dors WHERE id = ?', { dorId })
    return { success = true }
end)
