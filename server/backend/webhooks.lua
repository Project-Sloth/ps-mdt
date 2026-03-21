function sendIncidentToDiscord(title, message, associatedData)
    local webhook = Config.Webhooks and Config.Webhooks.IncidentLog or ''
    if webhook == '' then return end

    if associatedData then
        message = message .. '\n\n--- Associated Data ---'
        message = message .. '\nCID: ' .. (associatedData.cid or 'N/A')
        message = message .. '\nGuilty: ' .. tostring(associatedData.guilty or 'N/A')
        if associatedData.charges then
            message = message .. '\nCharges: ' .. tostring(associatedData.charges)
        end
        message = message .. '\nFine: $' .. tostring(associatedData.fine or 0)
        message = message .. '\nSentence: ' .. tostring(associatedData.sentence or 0)
    end

    PerformHttpRequest(webhook, function(err, text, headers) end, 'POST', json.encode({
        embeds = {{
            title = title,
            color = 3989503,
            description = message,
            footer = { text = 'ps-mdt' },
            timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ'),
        }}
    }), { ['Content-Type'] = 'application/json' })
end

