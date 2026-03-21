-- Sound definitions
local MDTSounds = {
    open = {
        audioName = 'ATM_WINDOW',
        audioRef = 'HUD_FRONTEND_DEFAULT_SOUNDSET'
    },
    close = {
        audioName = 'BACK',
        audioRef = 'HUD_FRONTEND_DEFAULT_SOUNDSET'
    },
    buttonClick = {
        audioName = 'SELECT',
        audioRef = 'HUD_FRONTEND_DEFAULT_SOUNDSET'
    },
}

-- Play sound based on input
function PlayMDTSound(soundType)
    if not MDTSounds[soundType] then
        ps.debug('Unknown MDT sound type:', soundType)
        return
    end

    local sound = MDTSounds[soundType]
    exports.ps_lib:PlaySound({
        audioName = sound.audioName,
        audioRef = sound.audioRef
    })

    ps.debug('Playing MDT sound:', soundType)
end