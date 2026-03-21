local resourceName = tostring(GetCurrentResourceName())

local function getDepartment(src)
    return ps.getJobName(src) or 'police'
end

ps.registerCallback(resourceName .. ':server:getNotes', function(source)
    local src = source
    if not CheckAuth(src) then return { success = false } end

    local citizenid = ps.getIdentifier(src)
    if not citizenid then
        return { success = false, message = 'Missing citizen id' }
    end

    local department = getDepartment(src)

    local departmentNotes = MySQL.scalar.await(
        'SELECT content FROM mdt_department_notes WHERE department = ? LIMIT 1',
        { department }
    )

    local personalNotes = MySQL.scalar.await(
        'SELECT content FROM mdt_notes WHERE owner = ? LIMIT 1',
        { citizenid }
    )

    return {
        success = true,
        department = departmentNotes or '',
        personal = personalNotes or ''
    }
end)

ps.registerCallback(resourceName .. ':server:saveNotes', function(source, data)
    local src = source
    if not CheckAuth(src) then return { success = false } end

    local citizenid = ps.getIdentifier(src)
    if not citizenid then
        return { success = false, message = 'Missing citizen id' }
    end

    local department = getDepartment(src)
    local departmentContent = data and data.department or ''
    local personalContent = data and data.personal or ''

    MySQL.query.await([[
        INSERT INTO mdt_department_notes (department, content, updated_at)
        VALUES (?, ?, NOW())
        ON DUPLICATE KEY UPDATE content = VALUES(content), updated_at = NOW()
    ]], { department, departmentContent })

    local existingId = MySQL.scalar.await(
        'SELECT id FROM mdt_notes WHERE owner = ? LIMIT 1',
        { citizenid }
    )

    if existingId then
        MySQL.query.await(
            'UPDATE mdt_notes SET content = ? WHERE id = ?',
            { personalContent, existingId }
        )
    else
        MySQL.query.await(
            'INSERT INTO mdt_notes (owner, content) VALUES (?, ?)',
            { citizenid, personalContent }
        )
    end

    return { success = true }
end)
