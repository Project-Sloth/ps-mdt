-- ============================================================================
--  Global search
-- ----------------------------------------------------------------------------
--  An officer with a plate or a name in hand didn't know which tab to look in.
--  A plate could be a vehicle, a BOLO or a report; a name could be a citizen or a
--  warrant. The only way to find out was to try each tab in turn.
--
--  This asks all of them at once. Two rules keep that from becoming a side door
--  into data the tabs themselves wouldn't show:
--
--   * Every source is gated on the permission that already guards its tab.
--   * Reports and warrants go through BuildReportAccessClause() — the SAME clause
--     the Reports tab uses. A report can be restricted to a job, a job type or a
--     single citizen, so querying mdt_reports directly would have handed a medic
--     the police paperwork the Reports tab correctly hides. Sharing the clause is
--     what stops the two drifting apart later.
--
--  CheckAuth already refuses anyone who isn't LEO, EMS or DOJ, so a civilian with
--  MDT access never reaches this at all.
-- ============================================================================

local resourceName = tostring(GetCurrentResourceName())

-- Per-source cap. The dropdown is a shortcut, not a results page: if the right
-- answer isn't in the first few, the officer should narrow the query.
local PER_TYPE = 5

-- Fewer characters than this matches half the database and helps nobody.
local MIN_QUERY = 3

--- Escape LIKE wildcards so a literal % can't turn one keystroke into a scan of
--- every table.
local function likeTerm(q)
    q = q:gsub('([%%_\\])', '\\%1')
    return '%' .. q .. '%'
end

ps.registerCallback(resourceName .. ':server:globalSearch', function(source, payload)
    local src = source
    if not CheckAuth(src) then return { results = {} } end

    payload = payload or {}
    local q = tostring(payload.query or ''):gsub('^%s+', ''):gsub('%s+$', '')
    if #q < MIN_QUERY then return { results = {} } end

    local like = likeTerm(q)
    local results = {}
    local function add(e) results[#results + 1] = e end

    -- Everything the report access clause needs, resolved once.
    local identifier = ps.getIdentifier(src)
    local job        = ps.getJobName(src)
    local jobType    = GetEffectiveJobType(src)
    local accessArgs = { jobType, jobType, jobType, identifier, job, jobType }

    local function withAccess(...)
        local args = {}
        for _, v in ipairs(accessArgs) do args[#args + 1] = v end
        for _, v in ipairs({ ... }) do args[#args + 1] = v end
        return args
    end

    -- ── Citizens ─────────────────────────────────────────────────────────────
    if CheckPermission(src, 'citizens_search') then
        local rows = MySQL.query.await([[
            SELECT p.citizenid,
                   CONCAT(
                       JSON_UNQUOTE(JSON_EXTRACT(p.charinfo, '$.firstname')), ' ',
                       JSON_UNQUOTE(JSON_EXTRACT(p.charinfo, '$.lastname'))
                   ) AS name,
                   JSON_UNQUOTE(JSON_EXTRACT(p.charinfo, '$.phone')) AS phone,
                   mp.profilepicture AS image
            FROM players p
            LEFT JOIN mdt_profiles mp ON mp.citizenid = p.citizenid COLLATE utf8mb4_general_ci
            HAVING name LIKE ? OR p.citizenid LIKE ? OR phone LIKE ?
            LIMIT ?
        ]], { like, like, like, PER_TYPE }) or {}

        for _, r in ipairs(rows) do
            add({
                type  = 'citizen',
                id    = r.citizenid,
                label = r.name,
                sub   = r.citizenid,
                icon  = 'person',
                -- A face is recognised faster than a name is read.
                image = (r.image and r.image ~= '') and r.image or nil,
            })
        end
    end

    -- ── Vehicles ─────────────────────────────────────────────────────────────
    if CheckPermission(src, 'vehicles_search') then
        -- The DB only knows "nero", but the UI shows "Truffade Nero" — so a search for
        -- the brand would find nothing. The shared vehicle table is already in memory:
        -- resolve the query to spawn names first, then look those up too.
        local models = VehicleModelsMatching(q, 25)
        local placeholders = {}
        local args = { like, like }
        for _, m in ipairs(models) do
            placeholders[#placeholders + 1] = '?'
            args[#args + 1] = m
        end
        args[#args + 1] = PER_TYPE

        local modelClause = #placeholders > 0
            and (' OR v.vehicle IN (' .. table.concat(placeholders, ',') .. ')')
            or ''

        local rows = MySQL.query.await(([[
            SELECT v.plate, v.vehicle, v.mdt_vehicle_image AS image,
                   CONCAT(
                       JSON_UNQUOTE(JSON_EXTRACT(p.charinfo, '$.firstname')), ' ',
                       JSON_UNQUOTE(JSON_EXTRACT(p.charinfo, '$.lastname'))
                   ) AS owner
            FROM player_vehicles v
            LEFT JOIN players p ON p.citizenid = v.citizenid COLLATE utf8mb4_general_ci
            WHERE (v.plate LIKE ? OR v.vehicle LIKE ?%s)
            LIMIT ?
        ]]):format(modelClause), args) or {}

        for _, r in ipairs(rows) do
            -- "nero" is what the game calls it. "Truffade Nero" is what a person does.
            local display = VehicleDisplayName(r.vehicle)
            add({
                type  = 'vehicle',
                id    = r.plate,
                label = r.plate,
                sub   = (r.owner and r.owner ~= '') and (display .. ' · ' .. r.owner) or display,
                icon  = 'directions_car',
                image = (r.image and r.image ~= '') and r.image or nil,
            })
        end
    end

    -- ── Active warrants ──────────────────────────────────────────────────────
    if CheckPermission(src, 'warrants_view') then
        local rows = MySQL.query.await(([[
            SELECT DISTINCT w.reportid, w.citizenid, mr.title,
                   CONCAT(
                       JSON_UNQUOTE(JSON_EXTRACT(p.charinfo, '$.firstname')), ' ',
                       JSON_UNQUOTE(JSON_EXTRACT(p.charinfo, '$.lastname'))
                   ) AS name
            FROM mdt_reports_warrants w
            INNER JOIN mdt_reports AS mr ON mr.id = w.reportid
            LEFT JOIN mdt_reports_restrictions AS mrr ON mr.id = mrr.reportid
            LEFT JOIN players p ON p.citizenid = w.citizenid COLLATE utf8mb4_general_ci
            WHERE w.expirydate > NOW() AND %s
            HAVING name LIKE ? OR w.citizenid LIKE ? OR title LIKE ?
            LIMIT ?
        ]]):format(BuildReportAccessClause()), withAccess(like, like, like, PER_TYPE)) or {}

        for _, r in ipairs(rows) do
            add({
                type  = 'warrant',
                -- A warrant opens its report; that's where the detail lives, and it's
                -- what clicking a warrant in the Warrants tab already does.
                id    = r.reportid,
                label = (r.name and r.name ~= '') and r.name or tostring(r.citizenid),
                sub   = r.title or ('Report #' .. tostring(r.reportid)),
                icon  = 'gavel',
            })
        end
    end

    -- ── BOLOs ────────────────────────────────────────────────────────────────
    if CheckPermission(src, 'bolos_view') then
        local rows = MySQL.query.await([[
            SELECT id, type, subject_id, subject_name
            FROM mdt_bolos
            WHERE status = 'active' AND (subject_id LIKE ? OR subject_name LIKE ?)
            ORDER BY id DESC
            LIMIT ?
        ]], { like, like, PER_TYPE }) or {}

        for _, r in ipairs(rows) do
            add({
                type  = 'bolo',
                id    = r.id,
                label = (r.subject_name and r.subject_name ~= '') and r.subject_name or tostring(r.subject_id),
                sub   = ('%s BOLO'):format(tostring(r.type or ''):upper()),
                icon  = 'campaign',
            })
        end
    end

    -- ── Reports ──────────────────────────────────────────────────────────────
    if CheckPermission(src, 'reports_view') then
        local rows = MySQL.query.await(([[
            SELECT DISTINCT mr.id, mr.title, mr.type
            FROM mdt_reports AS mr
            LEFT JOIN mdt_reports_restrictions AS mrr ON mr.id = mrr.reportid
            WHERE %s AND (mr.title LIKE ? OR mr.id LIKE ?)
            ORDER BY mr.id DESC
            LIMIT ?
        ]]):format(BuildReportAccessClause()), withAccess(like, like, PER_TYPE)) or {}

        for _, r in ipairs(rows) do
            add({
                type  = 'report',
                id    = r.id,
                label = r.title,
                sub   = ('#%s · %s'):format(tostring(r.id), tostring(r.type or 'Report')),
                icon  = 'description',
            })
        end
    end

    -- ── Cases ────────────────────────────────────────────────────────────────
    if CheckPermission(src, 'cases_view') then
        local rows = MySQL.query.await([[
            SELECT id, case_number, title, status
            FROM mdt_cases
            WHERE title LIKE ? OR case_number LIKE ?
            ORDER BY id DESC
            LIMIT ?
        ]], { like, like, PER_TYPE }) or {}

        for _, r in ipairs(rows) do
            add({
                type  = 'case',
                id    = r.id,
                label = r.title,
                sub   = ('%s · %s'):format(tostring(r.case_number or ('#' .. r.id)), tostring(r.status or 'open')),
                icon  = 'folder_open',
            })
        end
    end

    -- ── Weapons ──────────────────────────────────────────────────────────────
    if CheckPermission(src, 'weapons_search') then
        local rows = MySQL.query.await([[
            SELECT w.id, w.serial, w.weaponModel, w.weaponClass,
                   CONCAT(
                       JSON_UNQUOTE(JSON_EXTRACT(p.charinfo, '$.firstname')), ' ',
                       JSON_UNQUOTE(JSON_EXTRACT(p.charinfo, '$.lastname'))
                   ) AS owner
            FROM mdt_weapons w
            LEFT JOIN players p ON p.citizenid = w.owner
            WHERE w.serial LIKE ? OR w.weaponModel LIKE ?
            LIMIT ?
        ]], { like, like, PER_TYPE }) or {}

        for _, r in ipairs(rows) do
            local label = WeaponLabel(r.weaponModel)
            add({
                type  = 'weapon',
                -- The Weapons tab opens by row id, not by serial.
                id    = r.id,
                label = tostring(r.serial),
                sub   = (r.owner and r.owner ~= '')
                    and (label .. ' · ' .. r.owner)
                    or label,
                icon  = 'gpp_maybe',
            })
        end
    end

    -- ── Evidence ─────────────────────────────────────────────────────────────
    if CheckPermission(src, 'evidence_view') then
        local rows = MySQL.query.await([[
            SELECT id, title, type, serial
            FROM mdt_evidence_items
            WHERE title LIKE ? OR serial LIKE ?
            ORDER BY id DESC
            LIMIT ?
        ]], { like, like, PER_TYPE }) or {}

        for _, r in ipairs(rows) do
            add({
                type  = 'evidence',
                id    = r.id,
                label = tostring(r.title),
                sub   = (r.serial and r.serial ~= '') and tostring(r.serial) or tostring(r.type or 'Evidence'),
                icon  = 'inventory_2',
            })
        end
    end

    return { results = results }
end)
