local resourceName = tostring(GetCurrentResourceName())

ps.registerCallback(resourceName .. ':server:getEvidenceItems', function(source, page, limit, filters)
    local src = source
    if not CheckAuth(src) then return { success = false, error = 'Unauthorized' } end

    page = tonumber(page) or 1
    limit = tonumber(limit) or 20
    local offset = (page - 1) * limit

    local queryParts = { '1=1' }
    local values = {}

    if filters and filters.caseId then
        queryParts[#queryParts + 1] = 'case_id = ?'
        values[#values + 1] = tonumber(filters.caseId)
    end

    if filters and filters.type and filters.type ~= '' then
        queryParts[#queryParts + 1] = 'type = ?'
        values[#values + 1] = tostring(filters.type)
    end

    if filters and filters.stored ~= nil and filters.stored ~= '' then
        queryParts[#queryParts + 1] = 'stored = ?'
        values[#values + 1] = filters.stored and 1 or 0
    end

    local whereClause = table.concat(queryParts, ' AND ')
    local totalRow = MySQL.single.await(('SELECT COUNT(id) as total FROM mdt_evidence_items WHERE %s'):format(whereClause), values)
    local total = totalRow and totalRow.total or 0

    local listValues = { table.unpack(values) }
    listValues[#listValues + 1] = limit
    listValues[#listValues + 1] = offset

    local evidence = MySQL.query.await(([[
        SELECT id, case_id, report_id, title, type, serial, notes, location, stash_id, stored, last_holder, created_by, created_at, updated_at
        FROM mdt_evidence_items
        WHERE %s
        ORDER BY created_at DESC
        LIMIT ? OFFSET ?
    ]]):format(whereClause), listValues)

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

ps.registerCallback(resourceName .. ':server:searchEvidenceItems', function(source, query, page, limit)
    local src = source
    if not CheckAuth(src) then return { success = false, error = 'Unauthorized' } end

    if not query or tostring(query) == '' then
        return { success = true, data = { items = {}, total = 0, page = 1, limit = limit or 20 } }
    end

    query = tostring(query)
    page = tonumber(page) or 1
    limit = tonumber(limit) or 20
    local offset = (page - 1) * limit
    local likeQuery = '%' .. query .. '%'

    local totalRow = MySQL.single.await([[
        SELECT COUNT(id) as total
        FROM mdt_evidence_items
        WHERE title LIKE ? OR serial LIKE ? OR notes LIKE ? OR location LIKE ? OR stash_id LIKE ?
    ]], { likeQuery, likeQuery, likeQuery, likeQuery, likeQuery })

    local total = totalRow and totalRow.total or 0

    local evidence = MySQL.query.await([[
        SELECT id, case_id, report_id, title, type, serial, notes, location, stash_id, stored, last_holder, created_by, created_at, updated_at
        FROM mdt_evidence_items
        WHERE title LIKE ? OR serial LIKE ? OR notes LIKE ? OR location LIKE ? OR stash_id LIKE ?
        ORDER BY created_at DESC
        LIMIT ? OFFSET ?
    ]], { likeQuery, likeQuery, likeQuery, likeQuery, likeQuery, limit, offset })

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

ps.registerCallback(resourceName .. ':server:addEvidenceItem', function(source, payload)
    local src = source
    if not CheckAuth(src) then return { success = false, error = 'Unauthorized' } end

    payload = payload or {}
    local caseId = tonumber(payload.caseId)
    local reportId = tonumber(payload.reportId)
    local evidence = payload.evidence or payload

    if not evidence or not evidence.title then
        return { success = false, error = 'Invalid evidence: title is required' }
    end

    local evidenceId = MySQL.insert.await([[
        INSERT INTO mdt_evidence_items
        (case_id, report_id, title, type, serial, notes, location, stash_id, stored, last_holder, created_by)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ]], {
        caseId,
        reportId,
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

    if evidence.caseId then
        updates[#updates + 1] = 'case_id = ?'
        values[#values + 1] = tonumber(evidence.caseId)
    end

    if evidence.reportId then
        updates[#updates + 1] = 'report_id = ?'
        values[#values + 1] = tonumber(evidence.reportId)
    end

    if #updates == 0 then
        return { success = false, error = 'No updates provided' }
    end

    values[#values + 1] = evidenceId
    local success = MySQL.update.await(('UPDATE mdt_evidence_items SET %s WHERE id = ?'):format(table.concat(updates, ', ')), values)

    if not success then
        return { success = false, error = 'Failed to update evidence' }
    end

    if ps.auditLog then
        ps.auditLog(src, 'evidence_updated', 'evidence', evidenceId, evidence)
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
            fromCitizenId = fromCitizenId,
            toCitizenId = toCitizenId
        })
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

    local custody = MySQL.query.await([[
        SELECT id, evidence_id, from_citizenid, to_citizenid, action, notes, created_at
        FROM mdt_evidence_custody
        WHERE evidence_id = ?
        ORDER BY created_at DESC
    ]], { evidenceId })

    return custody or {}
end)

ps.registerCallback(resourceName .. ':server:logEvidenceViewed', function(source, evidenceId)
    local src = source
    if not CheckAuth(src) then return { success = false } end

    evidenceId = tonumber(evidenceId)
    if not evidenceId then return { success = false } end

    local citizenid = ps.getIdentifier(src)

    MySQL.insert.await([[
        INSERT INTO mdt_evidence_custody (evidence_id, from_citizenid, to_citizenid, action, notes)
        VALUES (?, NULL, ?, 'viewed', '')
    ]], { evidenceId, citizenid })

    return { success = true }
end)

ps.registerCallback(resourceName .. ':server:addEvidenceImage', function(source, evidenceId, image)
    local src = source
    if not CheckAuth(src) then return { success = false, error = 'Unauthorized' } end

    evidenceId = tonumber(evidenceId)
    if not evidenceId or not image then
        return { success = false, error = 'Invalid image' }
    end

    local url = image.url
    local label = image.label or ''

    -- Upload via FiveManage if base64 data is provided
    if image.data and image.filename then
        local contentType = image.contentType or ''
        if Config.Uploads and Config.Uploads.AllowedEvidenceImageTypes then
            local allowed = false
            for _, mime in ipairs(Config.Uploads.AllowedEvidenceImageTypes) do
                if mime == contentType then
                    allowed = true
                    break
                end
            end
            if not allowed then
                return { success = false, error = 'Unsupported image type' }
            end
        end

        if not FiveManageUpload then
            return { success = false, error = 'FiveManage upload not available' }
        end

        local dataUri = image.data
        if type(dataUri) ~= 'string' or dataUri == '' then
            return { success = false, error = 'Invalid image data' }
        end

        local uploadedUrl, uploadError = FiveManageUpload(dataUri, image.filename)
        if not uploadedUrl then
            return { success = false, error = 'Upload failed: ' .. (uploadError or 'Unknown error') }
        end
        url = uploadedUrl
    end

    if not url or url == '' then
        return { success = false, error = 'Missing image URL' }
    end

    local imageId = MySQL.insert.await([[
        INSERT INTO mdt_evidence_images (evidence_id, url, label, uploaded_by)
        VALUES (?, ?, ?, ?)
    ]], { evidenceId, url, label, ps.getIdentifier(src) })

    if not imageId then
        return { success = false, error = 'Failed to add image' }
    end

    if ps.auditLog then
        ps.auditLog(src, 'evidence_image_added', 'evidence', evidenceId, {
            url = url,
            label = label
        })
    end

    return { success = true, id = imageId, url = url }
end)

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

local function linkReportToCase(reportId, caseId, citizenid)
    if not reportId or not caseId then
        return
    end
    MySQL.insert.await([[
        INSERT IGNORE INTO mdt_case_reports (case_id, report_id, linked_by)
        VALUES (?, ?, ?)
    ]], { caseId, reportId, citizenid })
end

ps.registerCallback(resourceName .. ':server:linkEvidenceToCase', function(source, evidenceId, caseId, reportId)
    local src = source
    if not CheckAuth(src) then return { success = false, error = 'Unauthorized' } end

    evidenceId = tonumber(evidenceId)
    reportId = tonumber(reportId)

    -- Support case number format like "CASE-2026-003" by looking up the numeric ID
    local numericCaseId = tonumber(caseId)
    if not numericCaseId and type(caseId) == 'string' and caseId ~= '' then
        local row = MySQL.single.await('SELECT id FROM mdt_cases WHERE case_number = ? LIMIT 1', { caseId })
        if row then
            numericCaseId = row.id
        end
    end
    caseId = numericCaseId

    if not evidenceId or not caseId then
        return { success = false, error = 'Invalid evidence or case' }
    end

    MySQL.update.await('UPDATE mdt_evidence_items SET case_id = ? WHERE id = ?', { caseId, evidenceId })
    if reportId then
        linkReportToCase(reportId, caseId, ps.getIdentifier(src))
    end

    if ps.auditLog then
        ps.auditLog(src, 'evidence_linked_case', 'evidence', evidenceId, {
            caseId = caseId,
            reportId = reportId
        })
    end

    return { success = true }
end)

ps.registerCallback(resourceName .. ':server:linkEvidenceToReport', function(source, evidenceId, reportId)
    local src = source
    if not CheckAuth(src) then return { success = false, error = 'Unauthorized' } end

    evidenceId = tonumber(evidenceId)
    reportId = tonumber(reportId)

    if not evidenceId or not reportId then
        return { success = false, error = 'Invalid evidence or report' }
    end

    MySQL.update.await('UPDATE mdt_evidence_items SET report_id = ? WHERE id = ?', { reportId, evidenceId })

    if ps.auditLog then
        ps.auditLog(src, 'evidence_linked_report', 'evidence', evidenceId, {
            reportId = reportId
        })
    end

    return { success = true }
end)

ps.registerCallback(resourceName .. ':server:createCaseFromEvidence', function(source, evidenceId, reportId)
    local src = source
    if not CheckAuth(src) then return { success = false, error = 'Unauthorized' } end

    evidenceId = tonumber(evidenceId)
    reportId = tonumber(reportId)
    if not evidenceId then
        return { success = false, error = 'Invalid evidence' }
    end

    local citizenid = ps.getIdentifier(src)
    local createdByName = (ps.getMetadata(src, 'callsign') or '') .. ' ' .. (ps.getPlayerName(src) or '')
    createdByName = createdByName:gsub('^%s+', ''):gsub('%s+$', '')

    local caseId = MySQL.insert.await([[INSERT INTO mdt_cases
        (case_number, title, summary, status, priority, assigned_department, created_by, created_by_name)
        VALUES ('', ?, ?, 'open', 'medium', ?, ?, ?)
    ]], { 'Evidence Follow-up', 'Case created from evidence link', ps.getJobName(src) or 'police', citizenid, createdByName })

    if not caseId then
        return { success = false, error = 'Failed to create case' }
    end

    local caseNumber = ('CASE-%s-%05d'):format(os.date('%Y'), caseId)
    MySQL.update.await('UPDATE mdt_cases SET case_number = ? WHERE id = ?', { caseNumber, caseId })
    MySQL.update.await('UPDATE mdt_evidence_items SET case_id = ? WHERE id = ?', { caseId, evidenceId })
    if reportId then
        linkReportToCase(reportId, caseId, citizenid)
    end

    if ps.auditLog then
        ps.auditLog(src, 'case_created_from_evidence', 'case', caseId, {
            evidenceId = evidenceId,
            reportId = reportId
        })
    end

    return { success = true, caseId = caseId, caseNumber = caseNumber }
end)

RegisterNetEvent(resourceName .. ':server:openEvidenceStash', function(stashId)
    local src = source
    if not CheckAuth(src) then return end

    if not stashId or stashId == '' then return end

    exports['qb-inventory']:OpenInventory(src, stashId, {
        maxweight = 4000000,
        slots = 500,
    })
end)
