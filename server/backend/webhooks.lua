-- Send incident log to FiveManage
function sendIncidentLog(title, message, associatedData)
    if not FiveManageQueueLog then return end

    local metadata = {}
    if associatedData then
        metadata.cid = associatedData.cid or 'N/A'
        metadata.guilty = tostring(associatedData.guilty or 'N/A')
        metadata.charges = associatedData.charges or nil
        metadata.fine = associatedData.fine or 0
        metadata.sentence = associatedData.sentence or 0
    end

    FiveManageQueueLog({
        action = 'incident_report',
        category = 'incidents',
        message = title .. ': ' .. message,
        metadata = metadata
    })
end
