local resourceName = tostring(GetCurrentResourceName())

local function getActorData(src)
    if not src then
        return {
            citizenid = nil,
            name = 'System'
        }
    end

    local citizenid = ps.getIdentifier(src)
    local name = ps.getPlayerName(src) or 'Unknown'
    local callsign = ps.getMetadata(src, 'callsign')
    if callsign and callsign ~= '' then
        name = callsign .. ' ' .. name
    end

    return {
        citizenid = citizenid,
        name = name
    }
end

local function writeAuditLog(src, action, entityType, entityId, details)
    -- Check if this action's category is tracked
    if ps.isActionTracked and not ps.isActionTracked(action) then
        return
    end

    local actor = getActorData(src)

    MySQL.insert.await([[
        INSERT INTO mdt_audit_logs (actor_citizenid, actor_name, action, entity_type, entity_id, details)
        VALUES (?, ?, ?, ?, ?, ?)
    ]], {
        actor.citizenid,
        actor.name,
        action,
        entityType,
        entityId and tostring(entityId) or nil,
        details and json.encode(details) or nil
    })

    -- Forward to FiveManage Logs (batched, non-blocking)
    if FiveManageQueueLog then
        FiveManageQueueLog({
            action         = action,
            actorName      = actor.name,
            actorCitizenid = actor.citizenid,
            entityType     = entityType,
            entityId       = entityId and tostring(entityId) or nil,
            details        = details,
        })
    end
end

ps.auditLog = writeAuditLog

ps.registerCallback(resourceName .. ':server:getAuditLogs', function(source, params)
    local src = source
    if not CheckAuth(src) then return { items = {}, total = 0 } end

    params = params or {}
    local entityType = params.entityType
    local entityId = params.entityId
    local search = params.search and tostring(params.search) or nil
    local page = tonumber(params.page) or 1
    local perPage = tonumber(params.limit) or 25
    if perPage > 200 then perPage = 200 end
    local offset = (page - 1) * perPage

    local values = {}
    local countValues = {}
    local conditions = {}

    if entityType then
        conditions[#conditions + 1] = 'entity_type = ?'
        values[#values + 1] = entityType
        countValues[#countValues + 1] = entityType
    end

    if entityId then
        conditions[#conditions + 1] = 'entity_id = ?'
        values[#values + 1] = tostring(entityId)
        countValues[#countValues + 1] = tostring(entityId)
    end

    if search and search ~= '' then
        conditions[#conditions + 1] = '(actor_name LIKE ? OR action LIKE ? OR entity_type LIKE ?)'
        local searchPattern = '%' .. search .. '%'
        values[#values + 1] = searchPattern
        values[#values + 1] = searchPattern
        values[#values + 1] = searchPattern
        countValues[#countValues + 1] = searchPattern
        countValues[#countValues + 1] = searchPattern
        countValues[#countValues + 1] = searchPattern
    end

    local whereClause = ''
    if #conditions > 0 then
        whereClause = 'WHERE ' .. table.concat(conditions, ' AND ')
    end

    local totalRow = MySQL.single.await(([[
        SELECT COUNT(*) as total FROM mdt_audit_logs %s
    ]]):format(whereClause), countValues)
    local total = totalRow and totalRow.total or 0

    values[#values + 1] = perPage
    values[#values + 1] = offset

    local rows = MySQL.query.await(([[
        SELECT id, actor_citizenid, actor_name, action, entity_type, entity_id, details, created_at
        FROM mdt_audit_logs
        %s
        ORDER BY id DESC
        LIMIT ? OFFSET ?
    ]]):format(whereClause), values)

    return {
        items = rows or {},
        total = total,
        page = page,
        perPage = perPage
    }
end)

ps.registerCallback(resourceName .. ':server:getAuditLogsByCase', function(source, caseId, page, limit)
    local src = source
    if not CheckAuth(src) then return {} end

    caseId = tonumber(caseId)
    if not caseId then return {} end

    page = tonumber(page) or 1
    local max = tonumber(limit) or 10
    if max > 200 then
        max = 200
    end
    local offset = (page - 1) * max

    local totalRow = MySQL.single.await([[
        SELECT COUNT(id) as total
        FROM mdt_audit_logs
        WHERE (entity_type = 'case' AND entity_id = ?)
           OR (entity_type = 'evidence' AND entity_id IN (
                SELECT id FROM mdt_evidence_items WHERE case_id = ?
           ))
           OR (entity_type = 'case_attachment' AND entity_id IN (
                SELECT id FROM mdt_case_attachments WHERE case_id = ?
           ))
    ]], { tostring(caseId), caseId, caseId })

    local rows = MySQL.query.await([[
        SELECT id, actor_citizenid, actor_name, action, entity_type, entity_id, details, created_at
        FROM mdt_audit_logs
        WHERE (entity_type = 'case' AND entity_id = ?)
           OR (entity_type = 'evidence' AND entity_id IN (
                SELECT id FROM mdt_evidence_items WHERE case_id = ?
           ))
           OR (entity_type = 'case_attachment' AND entity_id IN (
                SELECT id FROM mdt_case_attachments WHERE case_id = ?
           ))
        ORDER BY id DESC
        LIMIT ? OFFSET ?
    ]], { tostring(caseId), caseId, caseId, max, offset })

    return {
        items = rows or {},
        total = totalRow and totalRow.total or 0,
        page = page,
        limit = max
    }
end)

return {
    write = writeAuditLog
}
