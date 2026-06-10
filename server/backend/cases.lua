local resourceName = tostring(GetCurrentResourceName())

local function buildCaseNumber(id)
    local year = os.date('%Y')
    return ('CASE-%s-%05d'):format(year, id)
end

local function normalizeStatus(status)
    local value = status and tostring(status):lower() or 'open'
    if value == 'open' or value == 'in_progress' or value == 'closed' then
        return value
    end
    if value == 'in progress' then
        return 'in_progress'
    end
    return 'open'
end

local function getOfficerDisplayName(src)
    local callsign = ps.getMetadata(src, 'callsign')
    local name = ps.getPlayerName(src) or 'Unknown'
    if callsign and callsign ~= '' then
        return callsign .. ' ' .. name
    end
    return name
end

ps.registerCallback(resourceName .. ':server:createCase', function(source, payload)
    local src = source
    if not CheckAuth(src) then return { success = false, error = 'Unauthorized' } end

    payload = payload or {}
    local title = payload.title or 'Untitled Case'
    local summary = payload.summary or ''
    local status = normalizeStatus(payload.status)
    local priority = payload.priority or 'medium'
    local department = payload.department or ps.getJobName(src) or 'police'

    local citizenid = ps.getIdentifier(src)
    if not citizenid then
        return { success = false, error = 'Missing citizen id' }
    end

    local createdByName = getOfficerDisplayName(src)

    local caseId = MySQL.insert.await([[INSERT INTO mdt_cases
        (case_number, title, summary, status, priority, assigned_department, created_by, created_by_name)
        VALUES ('', ?, ?, ?, ?, ?, ?, ?)
    ]], { title, summary, status, priority, department, citizenid, createdByName })

    if not caseId then
        return { success = false, error = 'Failed to create case' }
    end

    local caseNumber = buildCaseNumber(caseId)
    MySQL.update.await('UPDATE mdt_cases SET case_number = ? WHERE id = ?', { caseNumber, caseId })

    if ps.auditLog then
        ps.auditLog(src, 'case_created', 'case', caseId, {
            title = title,
            status = status,
            priority = priority
        })
    end

    return {
        success = true,
        caseId = caseId,
        caseNumber = caseNumber
    }
end)

ps.registerCallback(resourceName .. ':server:getCases', function(source, page, filters)
    local src = source
    if not CheckAuth(src) then return { cases = {}, hasMore = false } end

    page = tonumber(page) or 1
    local limit = Config.Pagination and Config.Pagination.Cases or 20
    local offset = (page - 1) * limit

    filters = filters or {}
    local clauses = {}
    local values = {}

    if filters.status then
        clauses[#clauses + 1] = 'status = ?'
        values[#values + 1] = normalizeStatus(filters.status)
    end

    if filters.department then
        clauses[#clauses + 1] = 'assigned_department = ?'
        values[#values + 1] = filters.department
    end

    local whereClause = ''
    if #clauses > 0 then
        whereClause = 'WHERE ' .. table.concat(clauses, ' AND ')
    end

    values[#values + 1] = limit
    values[#values + 1] = offset

    local rows = MySQL.query.await(([[
        SELECT mc.id, mc.case_number, mc.title, mc.summary, mc.status, mc.priority,
               mc.assigned_department, mc.created_by, mc.created_by_name,
               mc.created_at, mc.updated_at,
               mp.fullname AS primary_officer_name,
               mp.callsign AS primary_officer_callsign
        FROM mdt_cases mc
        LEFT JOIN mdt_case_officers mco ON mco.case_id = mc.id AND mco.role = 'primary'
        LEFT JOIN mdt_profiles mp ON mp.citizenid COLLATE utf8mb4_general_ci = mco.citizenid COLLATE utf8mb4_general_ci
        %s
        ORDER BY mc.updated_at DESC
        LIMIT ? OFFSET ?
    ]]):format(whereClause), values)

    return {
        cases = rows or {},
        hasMore = rows and #rows >= limit or false
    }
end)

ps.registerCallback(resourceName .. ':server:getCase', function(source, caseId)
    local src = source
    if not CheckAuth(src) then return { success = false, error = 'Unauthorized' } end

    caseId = tonumber(caseId)
    if not caseId then
        return { success = false, error = 'Invalid case id' }
    end

    local caseRow = MySQL.single.await('SELECT * FROM mdt_cases WHERE id = ?', { caseId })
    if not caseRow then
        return { success = false, error = 'Case not found' }
    end

    local officers = MySQL.query.await([[
        SELECT mco.citizenid, mco.role, mco.assigned_by, mco.assigned_at,
               mp.fullname, mp.callsign, mp.badge_number, mp.rank, mp.department
        FROM mdt_case_officers mco
        LEFT JOIN mdt_profiles mp ON mp.citizenid COLLATE utf8mb4_general_ci = mco.citizenid COLLATE utf8mb4_general_ci
        WHERE mco.case_id = ?
        ORDER BY mco.assigned_at ASC
    ]], { caseId })

    local attachments = MySQL.query.await([[
        SELECT id, type, url, label, uploaded_by, uploaded_at
        FROM mdt_case_attachments
        WHERE case_id = ?
        ORDER BY uploaded_at DESC
    ]], { caseId })

    local reports = MySQL.query.await([[
        SELECT mr.id, mr.title, mr.type, mr.datecreated
        FROM mdt_case_reports mcr
        INNER JOIN mdt_reports mr ON mr.id = mcr.report_id
        WHERE mcr.case_id = ?
        ORDER BY mr.datecreated DESC
    ]], { caseId })

    local notes = MySQL.query.await([[
        SELECT id, content, author_name, created_at
        FROM mdt_case_notes
        WHERE case_id = ?
        ORDER BY created_at DESC
    ]], { caseId })

    return {
        success = true,
        data = {
            case = caseRow,
            officers = officers or {},
            attachments = attachments or {},
            evidence = {},
            reports = reports or {},
            notes = notes or {}
        }
    }
end)

ps.registerCallback(resourceName .. ':server:linkReportToCase', function(source, reportId, caseId)
    local src = source
    if not CheckAuth(src) then return { success = false, error = 'Unauthorized' } end

    reportId = tonumber(reportId)
    caseId = tonumber(caseId)
    if not reportId or not caseId then
        return { success = false, error = 'Invalid report or case' }
    end

    -- Validate report exists before linking
    local reportExists = MySQL.single.await('SELECT id FROM mdt_reports WHERE id = ?', { reportId })
    if not reportExists then
        return { success = false, error = 'Report #' .. tostring(reportId) .. ' does not exist' }
    end

    MySQL.insert.await([[
        INSERT IGNORE INTO mdt_case_reports (case_id, report_id, linked_by)
        VALUES (?, ?, ?)
    ]], { caseId, reportId, ps.getIdentifier(src) })

    return { success = true }
end)

ps.registerCallback(resourceName .. ':server:unlinkReportFromCase', function(source, reportId, caseId)
    local src = source
    if not CheckAuth(src) then return { success = false, error = 'Unauthorized' } end

    reportId = tonumber(reportId)
    caseId = tonumber(caseId)
    if not reportId or not caseId then
        return { success = false, error = 'Invalid report or case' }
    end

    MySQL.query.await('DELETE FROM mdt_case_reports WHERE case_id = ? AND report_id = ?', { caseId, reportId })
    return { success = true }
end)

ps.registerCallback(resourceName .. ':server:getCaseEvidencePage', function(source, caseId, page, limit)
    local src = source
    if not CheckAuth(src) then return { success = false, error = 'Unauthorized' } end

    caseId = tonumber(caseId)
    if not caseId then
        return { success = false, error = 'Invalid case id' }
    end

    page = tonumber(page) or 1
    limit = tonumber(limit) or 5
    local offset = (page - 1) * limit

    local totalRow = MySQL.single.await('SELECT COUNT(id) as total FROM mdt_evidence_items WHERE case_id = ?', { caseId })
    local total = totalRow and totalRow.total or 0

    local evidence = MySQL.query.await([[
        SELECT id, title, type, serial, notes, location, stash_id, stored, last_holder, created_by, created_at, updated_at
        FROM mdt_evidence_items
        WHERE case_id = ?
        ORDER BY created_at DESC
        LIMIT ? OFFSET ?
    ]], { caseId, limit, offset })

    -- Batch-load all images for returned evidence items (avoids N+1)
    if evidence and #evidence > 0 then
        local ids = {}
        local idLookup = {}
        for _, item in ipairs(evidence) do
            ids[#ids + 1] = item.id
            idLookup[item.id] = item
            item.images = {}
        end

        local placeholders = string.rep('?,', #ids - 1) .. '?'
        local images = MySQL.query.await(([[
            SELECT id, evidence_id, url, label, uploaded_by, uploaded_at
            FROM mdt_evidence_images
            WHERE evidence_id IN (%s)
            ORDER BY uploaded_at DESC
        ]]):format(placeholders), ids)

        for _, img in ipairs(images or {}) do
            local parent = idLookup[img.evidence_id]
            if parent then
                parent.images[#parent.images + 1] = {
                    id = img.id,
                    url = img.url,
                    label = img.label,
                    uploaded_by = img.uploaded_by,
                    uploaded_at = img.uploaded_at
                }
            end
        end
    end

    return {
        success = true,
        data = {
            items = evidence or {},
            total = total,
            page = page,
            limit = limit
        }
    }
end)

ps.registerCallback(resourceName .. ':server:updateCase', function(source, caseId, payload)
    local src = source
    if not CheckAuth(src) then return { success = false, error = 'Unauthorized' } end

    caseId = tonumber(caseId)
    if not caseId then
        return { success = false, error = 'Invalid case id' }
    end

    payload = payload or {}
    local status = payload.status and normalizeStatus(payload.status) or nil
    local priority = payload.priority

    local updates = {}
    local values = {}

    if payload.title then
        updates[#updates + 1] = 'title = ?'
        values[#values + 1] = payload.title
    end

    if payload.summary then
        updates[#updates + 1] = 'summary = ?'
        values[#values + 1] = payload.summary
    end

    if status then
        updates[#updates + 1] = 'status = ?'
        values[#values + 1] = status
    end

    if priority then
        updates[#updates + 1] = 'priority = ?'
        values[#values + 1] = priority
    end

    if payload.department then
        updates[#updates + 1] = 'assigned_department = ?'
        values[#values + 1] = payload.department
    end

    if #updates == 0 then
        return { success = false, error = 'No updates provided' }
    end

    values[#values + 1] = caseId
    local success = MySQL.update.await(('UPDATE mdt_cases SET %s WHERE id = ?'):format(table.concat(updates, ', ')), values)

    if not success then
        return { success = false, error = 'Failed to update case' }
    end

    if ps.auditLog then
        ps.auditLog(src, 'case_updated', 'case', caseId, payload)
    end

    return { success = true }
end)

ps.registerCallback(resourceName .. ':server:deleteCase', function(source, caseId)
    local src = source
    if not CheckAuth(src) then return { success = false, error = 'Unauthorized' } end

    caseId = tonumber(caseId)
    if not caseId then
        return { success = false, error = 'Invalid case id' }
    end

    local caseRow = MySQL.single.await('SELECT title FROM mdt_cases WHERE id = ?', { caseId })
    local success = MySQL.query.await('DELETE FROM mdt_cases WHERE id = ?', { caseId })

    if not success then
        return { success = false, error = 'Failed to delete case' }
    end

    if ps.auditLog then
        ps.auditLog(src, 'case_deleted', 'case', caseId, {
            title = caseRow and caseRow.title or ''
        })
    end

    return { success = true }
end)

ps.registerCallback(resourceName .. ':server:assignCaseOfficer', function(source, caseId, officerCitizenId, role)
    local src = source
    if not CheckAuth(src) then return { success = false, error = 'Unauthorized' } end

    caseId = tonumber(caseId)
    if not caseId or not officerCitizenId then
        return { success = false, error = 'Invalid case or officer' }
    end

    role = role or 'assisting'

    local insertId = MySQL.insert.await([[
        INSERT INTO mdt_case_officers (case_id, citizenid, role, assigned_by)
        VALUES (?, ?, ?, ?)
    ]], { caseId, officerCitizenId, role, ps.getIdentifier(src) })

    if not insertId then
        return { success = false, error = 'Failed to assign officer' }
    end

    if ps.auditLog then
        ps.auditLog(src, 'case_officer_assigned', 'case', caseId, {
            officer = officerCitizenId,
            role = role
        })
    end

    return { success = true }
end)

ps.registerCallback(resourceName .. ':server:removeCaseOfficer', function(source, caseId, officerCitizenId)
    local src = source
    if not CheckAuth(src) then return { success = false, error = 'Unauthorized' } end

    caseId = tonumber(caseId)
    if not caseId or not officerCitizenId then
        return { success = false, error = 'Invalid case or officer' }
    end

    local success = MySQL.query.await([[
        DELETE FROM mdt_case_officers WHERE case_id = ? AND citizenid = ?
    ]], { caseId, officerCitizenId })

    if not success then
        return { success = false, error = 'Failed to remove officer' }
    end

    if ps.auditLog then
        ps.auditLog(src, 'case_officer_removed', 'case', caseId, {
            officer = officerCitizenId
        })
    end

    return { success = true }
end)

ps.registerCallback(resourceName .. ':server:addCaseAttachment', function(source, caseId, attachment)
    local src = source
    if not CheckAuth(src) then return { success = false, error = 'Unauthorized' } end

    caseId = tonumber(caseId)
    if not caseId or not attachment or not attachment.url then
        return { success = false, error = 'Invalid attachment' }
    end

    local attachmentId = MySQL.insert.await([[
        INSERT INTO mdt_case_attachments (case_id, type, url, label, uploaded_by)
        VALUES (?, ?, ?, ?, ?)
    ]], {
        caseId,
        attachment.type or 'document',
        attachment.url,
        attachment.label or '',
        ps.getIdentifier(src)
    })

    if not attachmentId then
        return { success = false, error = 'Failed to add attachment' }
    end

    if ps.auditLog then
        ps.auditLog(src, 'case_attachment_added', 'case', caseId, attachment)
    end

    return { success = true, id = attachmentId }
end)

ps.registerCallback(resourceName .. ':server:addCaseAttachmentUpload', function(source, caseId, attachment)
    local src = source
    if not CheckAuth(src) then return { success = false, error = 'Unauthorized' } end

    caseId = tonumber(caseId)
    if not caseId or not attachment or not attachment.data or not attachment.filename then
        return { success = false, error = 'Invalid attachment payload' }
    end

    local data = attachment.data
    local filename = attachment.filename
    local contentType = attachment.contentType or ''
    local label = attachment.label or ''
    local attachmentType = attachment.type or 'document'

    if Config.Uploads and Config.Uploads.AllowedAttachmentTypes then
        local allowed = false
        for _, mime in ipairs(Config.Uploads.AllowedAttachmentTypes) do
            if mime == contentType then
                allowed = true
                break
            end
        end
        if not allowed then
            return { success = false, error = 'Unsupported attachment type' }
        end
    end

    if not FiveManageUpload then
        return { success = false, error = 'FiveManage upload not available' }
    end

    local publicUrl, uploadError = FiveManageUpload(data, filename)
    if not publicUrl then
        return { success = false, error = 'Upload failed: ' .. (uploadError or 'Unknown error') }
    end

    local attachmentId = MySQL.insert.await([[
        INSERT INTO mdt_case_attachments (case_id, type, url, label, uploaded_by)
        VALUES (?, ?, ?, ?, ?)
    ]], {
        caseId,
        attachmentType,
        publicUrl,
        label,
        ps.getIdentifier(src)
    })

    if not attachmentId then
        return { success = false, error = 'Failed to save attachment' }
    end

    if ps.auditLog then
        ps.auditLog(src, 'case_attachment_uploaded', 'case', caseId, {
            label = label,
            url = publicUrl,
            contentType = contentType
        })
    end

    return { success = true, id = attachmentId, url = publicUrl }
end)

ps.registerCallback(resourceName .. ':server:removeCaseAttachment', function(source, attachmentId)
    local src = source
    if not CheckAuth(src) then return { success = false, error = 'Unauthorized' } end

    attachmentId = tonumber(attachmentId)
    if not attachmentId then
        return { success = false, error = 'Invalid attachment id' }
    end

    local attachment = MySQL.single.await('SELECT url, case_id FROM mdt_case_attachments WHERE id = ?', { attachmentId })
    local success = MySQL.query.await('DELETE FROM mdt_case_attachments WHERE id = ?', { attachmentId })

    if not success then
        return { success = false, error = 'Failed to remove attachment' }
    end

    if attachment and attachment.url and attachment.url:find('^/ps%-mdt%-v3/uploads/') then
        local path = attachment.url:gsub('^/ps%-mdt%-v3/', '')
        if path ~= '' then
            os.remove(path)
        end
    end

    if ps.auditLog then
        ps.auditLog(src, 'case_attachment_removed', 'case_attachment', attachmentId, {
            caseId = attachment and attachment.case_id or nil
        })
    end

    return { success = true }
end)

ps.registerCallback(resourceName .. ':server:addEvidenceItem', function(source, caseId, evidence)
    local src = source
    if not CheckAuth(src) then return { success = false, error = 'Unauthorized' } end

    caseId = tonumber(caseId)
    if not caseId or not evidence or not evidence.title then
        return { success = false, error = 'Invalid evidence' }
    end

    local evidenceId = MySQL.insert.await([[
        INSERT INTO mdt_evidence_items
        (case_id, title, type, serial, notes, location, stash_id, stored, last_holder, created_by)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ]], {
        caseId,
        evidence.title,
        evidence.type or 'Evidence',
        evidence.serial or '',
        evidence.notes or '',
        evidence.location or '',
        evidence.stashId or '',
        evidence.stored and 1 or 0,
        ps.getIdentifier(src),
        ps.getIdentifier(src)
    })

    if not evidenceId then
        return { success = false, error = 'Failed to add evidence' }
    end

    MySQL.insert.await([[
        INSERT INTO mdt_evidence_custody (evidence_id, from_citizenid, to_citizenid, action, notes)
        VALUES (?, ?, ?, 'collected', ?)
    ]], { evidenceId, nil, ps.getIdentifier(src), evidence.notes or '' })

    if ps.auditLog then
        ps.auditLog(src, 'evidence_added', 'evidence', evidenceId, evidence)
    end

    return { success = true, id = evidenceId }
end)

-- addEvidenceImage handler is in evidence.lua (not duplicated here)

ps.registerCallback(resourceName .. ':server:removeEvidenceImage', function(source, imageId)
    local src = source
    if not CheckAuth(src) then return { success = false, error = 'Unauthorized' } end

    imageId = tonumber(imageId)
    if not imageId then
        return { success = false, error = 'Invalid image id' }
    end

    local image = MySQL.single.await('SELECT url, evidence_id FROM mdt_evidence_images WHERE id = ?', { imageId })
    local success = MySQL.query.await('DELETE FROM mdt_evidence_images WHERE id = ?', { imageId })
    if not success then
        return { success = false, error = 'Failed to remove image' }
    end

    if image and image.url and image.url:find('^/ps%-mdt%-v3/uploads/') then
        local path = image.url:gsub('^/ps%-mdt%-v3/', '')
        if path ~= '' then
            os.remove(path)
        end
    end

    if ps.auditLog then
        ps.auditLog(src, 'evidence_image_removed', 'evidence_image', imageId, {
            evidenceId = image and image.evidence_id or nil
        })
    end

    return { success = true }
end)

ps.registerCallback(resourceName .. ':server:updateEvidenceItem', function(source, evidenceId, evidence)
    local src = source
    if not CheckAuth(src) then return { success = false, error = 'Unauthorized' } end

    evidenceId = tonumber(evidenceId)
    if not evidenceId or not evidence then
        return { success = false, error = 'Invalid evidence' }
    end

    local updates = {}
    local values = {}

    if evidence.title then
        updates[#updates + 1] = 'title = ?'
        values[#values + 1] = evidence.title
    end
    if evidence.type then
        updates[#updates + 1] = 'type = ?'
        values[#values + 1] = evidence.type
    end
    if evidence.serial then
        updates[#updates + 1] = 'serial = ?'
        values[#values + 1] = evidence.serial
    end
    if evidence.notes then
        updates[#updates + 1] = 'notes = ?'
        values[#values + 1] = evidence.notes
    end
    if evidence.location then
        updates[#updates + 1] = 'location = ?'
        values[#values + 1] = evidence.location
    end
    if evidence.stashId then
        updates[#updates + 1] = 'stash_id = ?'
        values[#values + 1] = evidence.stashId
    end
    if evidence.stored ~= nil then
        updates[#updates + 1] = 'stored = ?'
        values[#values + 1] = evidence.stored and 1 or 0
    end

    if #updates == 0 then
        return { success = false, error = 'No updates provided' }
    end

    updates[#updates + 1] = 'last_holder = ?'
    values[#values + 1] = ps.getIdentifier(src)

    values[#values + 1] = evidenceId

    local success = MySQL.update.await(('UPDATE mdt_evidence_items SET %s WHERE id = ?'):format(table.concat(updates, ', ')), values)
    if not success then
        return { success = false, error = 'Failed to update evidence' }
    end

    MySQL.insert.await([[
        INSERT INTO mdt_evidence_custody (evidence_id, from_citizenid, to_citizenid, action, notes)
        VALUES (?, ?, ?, 'updated', ?)
    ]], { evidenceId, nil, ps.getIdentifier(src), evidence.notes or '' })

    if ps.auditLog then
        ps.auditLog(src, 'evidence_updated', 'evidence', evidenceId, evidence)
    end

    return { success = true }
end)

ps.registerCallback(resourceName .. ':server:transferEvidenceItem', function(source, evidenceId, toCitizenId, notes)
    local src = source
    if not CheckAuth(src) then return { success = false, error = 'Unauthorized' } end

    evidenceId = tonumber(evidenceId)
    if not evidenceId or not toCitizenId then
        return { success = false, error = 'Invalid evidence transfer' }
    end

    local fromCitizenId = ps.getIdentifier(src)
    MySQL.update.await('UPDATE mdt_evidence_items SET last_holder = ? WHERE id = ?', { toCitizenId, evidenceId })

    MySQL.insert.await([[
        INSERT INTO mdt_evidence_custody (evidence_id, from_citizenid, to_citizenid, action, notes)
        VALUES (?, ?, ?, 'transferred', ?)
    ]], { evidenceId, fromCitizenId, toCitizenId, notes or '' })

    if ps.auditLog then
        ps.auditLog(src, 'evidence_transferred', 'evidence', evidenceId, {
            to = toCitizenId,
            notes = notes
        })
    end

    return { success = true }
end)

ps.registerCallback(resourceName .. ':server:deleteEvidenceItem', function(source, evidenceId)
    local src = source
    if not CheckAuth(src) then return { success = false, error = 'Unauthorized' } end

    evidenceId = tonumber(evidenceId)
    if not evidenceId then
        return { success = false, error = 'Invalid evidence id' }
    end

    local success = MySQL.query.await('DELETE FROM mdt_evidence_items WHERE id = ?', { evidenceId })
    if not success then
        return { success = false, error = 'Failed to delete evidence' }
    end

    if ps.auditLog then
        ps.auditLog(src, 'evidence_deleted', 'evidence', evidenceId, {})
    end

    return { success = true }
end)

ps.registerCallback(resourceName .. ':server:getEvidenceCustody', function(source, evidenceId)
    local src = source
    if not CheckAuth(src) then return {} end

    evidenceId = tonumber(evidenceId)
    if not evidenceId then
        return {}
    end

    local rows = MySQL.query.await([[
        SELECT id, evidence_id, from_citizenid, to_citizenid, action, notes, created_at
        FROM mdt_evidence_custody
        WHERE evidence_id = ?
        ORDER BY id DESC
    ]], { evidenceId })

    return rows or {}
end)

-- Add a note to a case
ps.registerCallback(resourceName .. ':server:addCaseNote', function(source, caseId, content)
    local src = source
    if not CheckAuth(src) then return { success = false, error = 'Unauthorized' } end

    caseId = tonumber(caseId)
    if not caseId or not content or content == '' then
        return { success = false, error = 'Invalid case or empty note' }
    end

    local citizenId = ps.getIdentifier(src)
    local profile = MySQL.single.await('SELECT fullname FROM mdt_profiles WHERE citizenid = ?', { citizenId })
    local authorName = profile and profile.fullname or 'Unknown'

    MySQL.insert.await([[
        INSERT INTO mdt_case_notes (case_id, content, author_citizenid, author_name)
        VALUES (?, ?, ?, ?)
    ]], { caseId, content, citizenId, authorName })

    return { success = true }
end)

-- Delete a note from a case
ps.registerCallback(resourceName .. ':server:deleteCaseNote', function(source, noteId, caseId)
    local src = source
    if not CheckAuth(src) then return { success = false, error = 'Unauthorized' } end

    noteId = tonumber(noteId)
    caseId = tonumber(caseId)
    if not noteId or not caseId then
        return { success = false, error = 'Invalid note or case' }
    end

    MySQL.query.await('DELETE FROM mdt_case_notes WHERE id = ? AND case_id = ?', { noteId, caseId })
    return { success = true }
end)
