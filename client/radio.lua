local resourceName = GetCurrentResourceName()

-- ── Instructional-button code → label, and label → browser key ───────────────
-- GetControlInstructionalButton returns either "t_<char>" (a literal character
-- on the player's layout) or a "b_<code>" sprite id. We map the special-key
-- codes we care about for PTT to the matching value the NUI sees on a
-- KeyboardEvent (`code` for named keys, `key` for characters).
local BTN_LABEL <const> = {
    -- Mouse buttons → "mouse:<JS button index>" (0=left, 1=middle, 2=right,
    -- 3=back/X1, 4=forward/X2). FiveM numbers mouse buttons differently, hence
    -- the remap below.
    b_100 = 'mouse:0', -- LMB
    b_101 = 'mouse:2', -- RMB
    b_102 = 'mouse:1', -- MMB (middle click)
    b_103 = 'mouse:3', -- Mouse 4
    b_104 = 'mouse:4', -- Mouse 5
    b_199 = 'Escape', b_200 = 'Insert', b_201 = 'End',
    b_170 = 'F1', b_171 = 'F2', b_172 = 'F3', b_173 = 'F4', b_174 = 'F5', b_175 = 'F6',
    b_176 = 'F7', b_177 = 'F8', b_178 = 'F9', b_179 = 'F10', b_180 = 'F11', b_181 = 'F12',
    b_194 = 'ArrowUp', b_195 = 'ArrowDown', b_196 = 'ArrowLeft', b_197 = 'ArrowRight',
    b_1000 = 'ShiftLeft', b_1001 = 'ShiftRight',
    b_1002 = 'Tab', b_1003 = 'Enter', b_1004 = 'Backspace',
    b_1008 = 'Home', b_1009 = 'PageUp', b_1010 = 'PageDown',
    b_1011 = 'NumLock', b_1012 = 'CapsLock',
    b_1013 = 'ControlLeft', b_1014 = 'ControlRight',
    b_1015 = 'AltLeft', b_1016 = 'AltRight', b_1017 = 'ContextMenu',
    b_1018 = 'MetaLeft', b_1019 = 'MetaRight',
    b_2000 = 'Space',
}

-- Reads the browser-facing key bound to a keymapping command, or nil.
-- Sampled a few times because the native occasionally returns a stale value.
local function readBoundKey(commandName)
    if not commandName or commandName == '' then return nil end
    local hash = (GetHashKey(commandName)) | 0x80000000
    local seen, stable = nil, 0
    for _ = 1, 8 do
        local raw = GetControlInstructionalButton(0, hash, true)
        if type(raw) == 'string' and raw ~= '' then
            local val
            if raw:find('t_') then
                -- literal character (e.g. "t_R" → "R"); NUI matches on event.key
                val = (raw:gsub('t_', ''))
            else
                val = BTN_LABEL[raw] -- named key → KeyboardEvent.code
            end
            if val and val ~= '' then
                if seen == val then
                    stable = stable + 1
                    if stable >= 2 then return val end
                else
                    seen, stable = val, 0
                end
            end
        end
        Wait(0)
    end
    return seen
end

-- ── Resolve the active voice system + its trigger (cached) ───────────────────
local resolved -- nil = not yet resolved, false = none, table = config

local function commandExists(name)
    for _, c in ipairs(GetRegisteredCommands() or {}) do
        if c.name == name then return true end
    end
    return false
end

local function resolveSystem()
    if resolved ~= nil then return resolved end
    local cfg = Config.Radio
    if not cfg or not cfg.Enabled then resolved = false return resolved end

    local systemKey = cfg.VoiceSystem
    if systemKey == 'auto' then
        systemKey = nil
        for _, entry in ipairs(cfg.AutoDetect or {}) do
            if GetResourceState(entry.resource) == 'started' then
                systemKey = entry.system
                break
            end
        end
    end

    local sys = systemKey and cfg.Systems and cfg.Systems[systemKey]
    if not sys then resolved = false return resolved end

    -- Copy so we can fill in the fork-correct command without mutating config.
    local trigger = {
        system = systemKey,
        type = sys.type,
        start = sys.start,
        stop = sys.stop,
        resource = sys.resource,
        fn = sys.fn,
        keyCmd = sys.keyCmd,
    }

    -- For command-type systems, pick the actually-registered command (handles
    -- forks that renamed it) and derive the matching stop command.
    if trigger.type == 'command' and sys.startCandidates then
        for _, cand in ipairs(sys.startCandidates) do
            if commandExists(cand) then
                trigger.start = cand
                trigger.stop = '-' .. cand:sub(2)
                trigger.keyCmd = cand
                break
            end
        end
    end

    resolved = trigger
    return resolved
end

-- ── Push the resolved PTT key + enabled flag to the NUI ──────────────────────
function SendRadioConfig()
    local cfg = Config.Radio
    if not cfg or not cfg.Enabled then
        SendNUI('radioConfig', { enabled = false })
        return
    end
    local trigger = resolveSystem()
    if not trigger then
        SendNUI('radioConfig', { enabled = false })
        return
    end
    local key = readBoundKey(trigger.keyCmd) or cfg.PTTKey or 'AltLeft'
    SendNUI('radioConfig', { enabled = true, key = key })
end

-- ── Drive the active voice system ────────────────────────────────────────────
local radioTalking = false

local function setRadioTalking(state)
    state = state == true
    if state == radioTalking then return end -- de-dupe key repeat / double events

    local trigger = resolveSystem()
    if not trigger then return end

    radioTalking = state
    if trigger.type == 'command' then
        local cmd = state and trigger.start or trigger.stop
        if cmd and cmd ~= '' then ExecuteCommand(cmd) end
    elseif trigger.type == 'export' then
        if trigger.resource and trigger.fn and GetResourceState(trigger.resource) == 'started' then
            pcall(function() exports[trigger.resource][trigger.fn](state) end)
        end
    end
end

-- Exposed so the MDT close path can force-stop a hanging transmission.
function StopMdtRadio()
    setRadioTalking(false)
end

RegisterNUICallback('radioPTT', function(data, cb)
    local talking = type(data) == 'table' and data.talking == true
    -- Allow release even after close; only block a fresh press when closed.
    if talking and not MDTOpen then cb({ ok = false }) return end
    setRadioTalking(talking)
    cb({ ok = true })
end)

-- If the voice resource restarts, re-resolve next time.
AddEventHandler('onClientResourceStart', function(res)
    if res == 'pma-voice' or res == 'saltychat' or res == 'yaca-voice' then
        resolved = nil
    end
end)