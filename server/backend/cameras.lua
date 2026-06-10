local resourceName = tostring(GetCurrentResourceName())

-- Get available camera models for camera creation
ps.registerCallback(resourceName .. ':server:getCameraModels', function(source)
    -- Import Camera models from main cameras.lua
    local Camera = _G.Camera or {}
    local models = {}

    for key, hash in pairs(Camera.models or {}) do
        -- Format the label nicely
        local displayName = key:gsub('_', ' '):upper()
        displayName = displayName:gsub('CAM', 'Camera')
        displayName = displayName:gsub('CCTV', 'CCTV')

        table.insert(models, {
            value = key,
            label = displayName .. ' (' .. hash .. ')',
            model = hash
        })
    end

    -- Sort models alphabetically by label for better UX
    table.sort(models, function(a, b) return a.label < b.label end)

    ps.debug('Providing ' .. #models .. ' camera models to client ' .. source)
    return models
end)

-- Validate camera model
ps.registerCallback(resourceName .. ':server:validateCameraModel', function(source, modelKey)
    -- Import Camera models from main cameras.lua
    local Camera = _G.Camera or {}
    local isValid = (Camera.models or {})[modelKey] ~= nil

    ps.debug('Validating camera model "' .. tostring(modelKey) .. '" for client ' .. source .. ': ' .. tostring(isValid))
    return isValid
end)