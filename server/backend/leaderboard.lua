local resourceName = tostring(GetCurrentResourceName())

local function format_time(time)
    if not time or time == 0 then return '0 seconds' end
    local days = math.floor(time / 86400)
    time = time % 86400
    local hours = math.floor(time / 3600)
    time = time % 3600
    local minutes = math.floor(time / 60)
    local seconds = time % 60

    local formatted = ''
    if days > 0 then formatted = formatted .. days .. (days == 1 and ' day ' or ' days ') end
    if hours > 0 then formatted = formatted .. hours .. (hours == 1 and ' hour ' or ' hours ') end
    if minutes > 0 then formatted = formatted .. minutes .. (minutes == 1 and ' minute ' or ' minutes ') end
    if seconds > 0 and days == 0 then formatted = formatted .. seconds .. (seconds == 1 and ' second' or ' seconds') end
    return formatted
end

ps.registerCallback(resourceName .. ':server:getLeaderboard', function(source)
    if not CheckAuth(source) then return {} end

    local hasTable = MySQL.scalar.await("SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = DATABASE() AND table_name = 'mdt_clocking'")

    local result = {}
    if hasTable and hasTable > 0 then
        local officers = MySQL.query.await('SELECT firstname, lastname, user_id, total_time FROM mdt_clocking ORDER BY total_time DESC LIMIT 25', {})
        if officers then
            for k, officer in ipairs(officers) do
                result[#result + 1] = {
                    rank = k,
                    name = (officer.firstname or '') .. ' ' .. (officer.lastname or ''),
                    callsign = officer.user_id or '',
                    totalTime = format_time(tonumber(officer.total_time) or 0),
                }
            end
        end
    else
        local sessions = MySQL.query.await([[
            SELECT p.fullname, p.citizenid, p.callsign,
                   SUM(TIMESTAMPDIFF(SECOND, s.login_at, COALESCE(s.logout_at, NOW()))) as total_time
            FROM mdt_profile_sessions s
            JOIN mdt_profiles p ON s.profile_id = p.id
            WHERE s.login_at IS NOT NULL
            GROUP BY p.id
            ORDER BY total_time DESC
            LIMIT 25
        ]], {})
        if sessions then
            for k, session in ipairs(sessions) do
                result[#result + 1] = {
                    rank = k,
                    name = session.fullname or 'Unknown',
                    callsign = session.callsign or session.citizenid or '',
                    totalTime = format_time(tonumber(session.total_time) or 0),
                }
            end
        end
    end

    return result
end)
