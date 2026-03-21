-- Command to open MDT
if not Config.Commands.Open.enabled then
    ps.debug('MDT Open Command is disabled in config, skipping command registration.')
else
    RegisterCommand(Config.Commands.Open.command, function()
        OpenMDT()
    end, false)

    -- Add chat suggestion
    TriggerEvent('chat:addSuggestion', '/' .. Config.Commands.Open.command, 'Open the MDT')

    ps.debug('MDT Open Command Enabled: ' .. Config.Commands.Open.command)
end
