-- ============================================================================
--  officer_status.lua  —  MDT officer availability status (client side)
-- ----------------------------------------------------------------------------
--  Responsibilities:
--    * Forwards the static status config (ids/labels/colors from
--      Config.OfficerStatus) to the NUI once on Map mount.
--    * Forwards the local officer's own status changes to the server.
--    * Relays real-time status broadcasts from the server straight into the
--      NUI via SendNUIMessage, mirroring the syncPatrols pattern already used
--      for patrol updates — no polling involved, the Map tab updates the
--      instant any officer in the same domain changes their status.
--
--  This file is intentionally separate from tracking.lua: it owns nothing
--  tracking.lua already owns (no shared state), so it can be dropped or
--  swapped out without touching patrol/vehicle tracking at all.
-- ============================================================================

local resourceName = tostring(GetCurrentResourceName())

-- ─── NUI → Server ───────────────────────────────────────────────────────────

RegisterNUICallback("getOfficerStatusConfig", function(_, cb)
    local result = ps.callback(resourceName .. ":server:getOfficerStatusConfig")
    cb(result or { statuses = {}, default = "active" })
end)

RegisterNUICallback("setOfficerStatus", function(data, cb)
    if not MDTOpen then cb({ success = false }) return end
    if type(data) ~= "table" or type(data.status) ~= "string" then
        cb({ success = false }) return
    end
    local note = type(data.note) == "string" and data.note or nil
    TriggerServerEvent(resourceName .. ":server:setOfficerStatus", data.status, note)
    cb({ success = true })
end)

-- ─── Server → NUI ───────────────────────────────────────────────────────────
-- Pushed by officer_status.lua on the server every time ANY officer in this
-- player's domain (police vs ems) changes status. The NUI patches just that
-- one officer's row/marker instead of re-fetching the whole tracking list.

RegisterNetEvent(resourceName .. ":client:syncOfficerStatus", function(payload)
    SendNUIMessage({ type = "syncOfficerStatus", data = payload })
end)
