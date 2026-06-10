local resourceName = tostring(GetCurrentResourceName())

RegisterNUICallback('createCase', function(data, cb)
    if not MDTOpen then
        cb({ success = false, message = 'MDT is not open' })
        return
    end

    local result = ps.callback(resourceName .. ':server:createCase', data)
    cb(result or { success = false })
end)

RegisterNUICallback('getCases', function(data, cb)
    if not MDTOpen then
        cb({ cases = {}, hasMore = false })
        return
    end

    local page = data and data.page or 1
    local filters = data and data.filters or {}
    local result = ps.callback(resourceName .. ':server:getCases', page, filters)
    cb(result or { cases = {}, hasMore = false })
end)

RegisterNUICallback('getCase', function(data, cb)
    if not MDTOpen then
        cb({ success = false, message = 'MDT is not open' })
        return
    end

    if not data or not data.caseId then
        cb({ success = false, message = 'Missing case ID' })
        return
    end

    local result = ps.callback(resourceName .. ':server:getCase', data.caseId)
    cb(result or { success = false })
end)

RegisterNUICallback('linkReportToCase', function(data, cb)
    if not MDTOpen then
        cb({ success = false, message = 'MDT is not open' })
        return
    end

    data = data or {}
    local result = ps.callback(
        resourceName .. ':server:linkReportToCase',
        data.reportId,
        data.caseId
    )
    cb(result or { success = false })
end)

RegisterNUICallback('unlinkReportFromCase', function(data, cb)
    if not MDTOpen then
        cb({ success = false, message = 'MDT is not open' })
        return
    end

    data = data or {}
    local result = ps.callback(
        resourceName .. ':server:unlinkReportFromCase',
        data.reportId,
        data.caseId
    )
    cb(result or { success = false })
end)

RegisterNUICallback('getCaseEvidencePage', function(data, cb)
    if not MDTOpen then
        cb({ success = false, message = 'MDT is not open' })
        return
    end

    if not data or not data.caseId then
        cb({ success = false, message = 'Missing case ID' })
        return
    end

    local result = ps.callback(
        resourceName .. ':server:getCaseEvidencePage',
        data.caseId,
        data.page,
        data.limit
    )
    cb(result or { success = false })
end)

RegisterNUICallback('updateCase', function(data, cb)
    if not MDTOpen then
        cb({ success = false, message = 'MDT is not open' })
        return
    end

    if not data or not data.caseId then
        cb({ success = false, message = 'Missing case ID' })
        return
    end

    local result = ps.callback(resourceName .. ':server:updateCase', data.caseId, data.payload or {})
    cb(result or { success = false })
end)

RegisterNUICallback('deleteCase', function(data, cb)
    if not MDTOpen then
        cb({ success = false, message = 'MDT is not open' })
        return
    end

    if not data or not data.caseId then
        cb({ success = false, message = 'Missing case ID' })
        return
    end

    local result = ps.callback(resourceName .. ':server:deleteCase', data.caseId)
    cb(result or { success = false })
end)

RegisterNUICallback('assignCaseOfficer', function(data, cb)
    if not MDTOpen then
        cb({ success = false, message = 'MDT is not open' })
        return
    end

    local result = ps.callback(
        resourceName .. ':server:assignCaseOfficer',
        data.caseId,
        data.citizenid,
        data.role
    )
    cb(result or { success = false })
end)

RegisterNUICallback('removeCaseOfficer', function(data, cb)
    if not MDTOpen then
        cb({ success = false, message = 'MDT is not open' })
        return
    end

    local result = ps.callback(
        resourceName .. ':server:removeCaseOfficer',
        data.caseId,
        data.citizenid
    )
    cb(result or { success = false })
end)

RegisterNUICallback('addCaseAttachment', function(data, cb)
    if not MDTOpen then
        cb({ success = false, message = 'MDT is not open' })
        return
    end

    local result = ps.callback(
        resourceName .. ':server:addCaseAttachment',
        data.caseId,
        data.attachment
    )
    cb(result or { success = false })
end)

RegisterNUICallback('addCaseAttachmentUpload', function(data, cb)
    if not MDTOpen then
        cb({ success = false, message = 'MDT is not open' })
        return
    end

    local result = ps.callback(
        resourceName .. ':server:addCaseAttachmentUpload',
        data.caseId,
        data.attachment
    )
    cb(result or { success = false })
end)

RegisterNUICallback('removeCaseAttachment', function(data, cb)
    if not MDTOpen then
        cb({ success = false, message = 'MDT is not open' })
        return
    end

    local result = ps.callback(resourceName .. ':server:removeCaseAttachment', data.attachmentId)
    cb(result or { success = false })
end)

RegisterNUICallback('addEvidenceItem', function(data, cb)
    if not MDTOpen then
        cb({ success = false, message = 'MDT is not open' })
        return
    end

    local result = ps.callback(
        resourceName .. ':server:addEvidenceItem',
        data.caseId,
        data.evidence
    )
    cb(result or { success = false })
end)

RegisterNUICallback('updateEvidenceItem', function(data, cb)
    if not MDTOpen then
        cb({ success = false, message = 'MDT is not open' })
        return
    end

    local result = ps.callback(
        resourceName .. ':server:updateEvidenceItem',
        data.evidenceId,
        data.evidence
    )
    cb(result or { success = false })
end)

RegisterNUICallback('transferEvidenceItem', function(data, cb)
    if not MDTOpen then
        cb({ success = false, message = 'MDT is not open' })
        return
    end

    local result = ps.callback(
        resourceName .. ':server:transferEvidenceItem',
        data.evidenceId,
        data.toCitizenId,
        data.notes
    )
    cb(result or { success = false })
end)

RegisterNUICallback('deleteEvidenceItem', function(data, cb)
    if not MDTOpen then
        cb({ success = false, message = 'MDT is not open' })
        return
    end

    local result = ps.callback(resourceName .. ':server:deleteEvidenceItem', data.evidenceId)
    cb(result or { success = false })
end)

RegisterNUICallback('getEvidenceCustody', function(data, cb)
    if not MDTOpen then
        cb({ success = false, message = 'MDT is not open' })
        return
    end

    local result = ps.callback(resourceName .. ':server:getEvidenceCustody', data.evidenceId)
    cb(result or {})
end)

RegisterNUICallback('linkEvidenceToCase', function(data, cb)
    if not MDTOpen then
        cb({ success = false, message = 'MDT is not open' })
        return
    end

    data = data or {}
    local result = ps.callback(
        resourceName .. ':server:linkEvidenceToCase',
        data.evidenceId,
        data.caseId,
        data.reportId
    )
    cb(result or { success = false })
end)

RegisterNUICallback('linkEvidenceToReport', function(data, cb)
    if not MDTOpen then
        cb({ success = false, message = 'MDT is not open' })
        return
    end

    data = data or {}
    local result = ps.callback(
        resourceName .. ':server:linkEvidenceToReport',
        data.evidenceId,
        data.reportId
    )
    cb(result or { success = false })
end)

RegisterNUICallback('createCaseFromEvidence', function(data, cb)
    if not MDTOpen then
        cb({ success = false, message = 'MDT is not open' })
        return
    end

    data = data or {}
    local result = ps.callback(
        resourceName .. ':server:createCaseFromEvidence',
        data.evidenceId,
        data.reportId
    )
    cb(result or { success = false })
end)

RegisterNUICallback('addEvidenceImage', function(data, cb)
    if not MDTOpen then
        cb({ success = false, message = 'MDT is not open' })
        return
    end

    local result = ps.callback(
        resourceName .. ':server:addEvidenceImage',
        data.evidenceId,
        data.image
    )
    cb(result or { success = false })
end)

RegisterNUICallback('removeEvidenceImage', function(data, cb)
    if not MDTOpen then
        cb({ success = false, message = 'MDT is not open' })
        return
    end

    local result = ps.callback(resourceName .. ':server:removeEvidenceImage', data.imageId)
    cb(result or { success = false })
end)

RegisterNUICallback('getEvidenceItems', function(data, cb)
    if not MDTOpen then
        cb({ success = false, message = 'MDT is not open' })
        return
    end

    data = data or {}
    local page = data.page or 1
    local limit = data.limit or 20
    local filters = data.filters or {}
    local result = ps.callback(resourceName .. ':server:getEvidenceItems', page, limit, filters)
    cb(result or { success = false })
end)

RegisterNUICallback('searchEvidenceItems', function(data, cb)
    if not MDTOpen then
        cb({ success = false, message = 'MDT is not open' })
        return
    end

    data = data or {}
    local query = data.query or ''
    local page = data.page or 1
    local limit = data.limit or 20
    local result = ps.callback(resourceName .. ':server:searchEvidenceItems', query, page, limit)
    cb(result or { success = false })
end)

RegisterNUICallback('logEvidenceViewed', function(data, cb)
    if not MDTOpen then
        cb({ success = false })
        return
    end

    if not data or not data.evidenceId then
        cb({ success = false })
        return
    end

    local result = ps.callback(resourceName .. ':server:logEvidenceViewed', data.evidenceId)
    cb(result or { success = false })
end)

RegisterNUICallback('addCaseNote', function(data, cb)
    if not MDTOpen then cb({ success = false }) return end
    if not data or not data.caseId or not data.content or data.content == '' then
        cb({ success = false, message = 'Missing case ID or note content' })
        return
    end
    local result = ps.callback(resourceName .. ':server:addCaseNote', data.caseId, data.content)
    cb(result or { success = false })
end)

RegisterNUICallback('deleteCaseNote', function(data, cb)
    if not MDTOpen then cb({ success = false }) return end
    if not data or not data.noteId or not data.caseId then
        cb({ success = false, message = 'Missing note ID or case ID' })
        return
    end
    local result = ps.callback(resourceName .. ':server:deleteCaseNote', data.noteId, data.caseId)
    cb(result or { success = false })
end)

RegisterNUICallback('openEvidenceStash', function(data, cb)
    if not MDTOpen then
        cb({ success = false, message = 'MDT is not open' })
        return
    end

    if not data or not data.stashId or data.stashId == '' then
        cb({ success = false, message = 'Missing stash ID' })
        return
    end

    TriggerServerEvent(resourceName .. ':server:openEvidenceStash', data.stashId)
    cb({ success = true })
end)
