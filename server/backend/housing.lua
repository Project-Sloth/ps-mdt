--[[
    server/backend/housing.lua

    Centralised housing / property database access for the MDT.

    Every housing resource (qbx_properties, ps-housing, qb-houses, ...) stores
    owned properties in a different table with different column names. Instead
    of hard-coding one schema, the MDT reads `Config.Housing` (see config.lua)
    and builds its queries from the mapping defined there.

    The rest of the MDT only ever calls the three helpers exposed here and never
    touches the housing tables directly:

        Housing.GetCountsByOwners(citizenids)
            -> { [citizenid] = numberOfProperties, ... }

        Housing.GetByOwner(citizenid)
            -> { { id, property_name, coords, keyholders }, ... }

        Housing.GetById(propertyId)
            -> { id, property_name, coords, owner, keyholders } | nil

    All rows are returned using the MDT's internal field names (id,
    property_name, coords, owner, keyholders) regardless of the real column
    names, so no other file needs to know which housing system is running.

    To switch housing systems you normally only change `Config.Housing.system`.
--]]

Housing = Housing or {}

local resolvedSchema = nil
local schemaChecked = false

-- Only allow plain SQL identifiers (letters, digits, underscore). Table and
-- column names from the config are interpolated directly into the query
-- string, so this guards against a misconfigured Config.Housing turning into
-- SQL injection or a malformed query.
local function validIdent(name)
    return type(name) == 'string' and name ~= '' and name:match('^[%w_]+$') ~= nil
end

-- Quote a (pre-validated) identifier.
local function qq(name)
    return '`' .. name .. '`'
end

local function disable(reason)
    print(('[ps-mdt] [housing] %s — the properties feature is disabled. Check Config.Housing.'):format(reason))
    return nil
end

-- Resolve the active schema from Config.Housing once and cache the result.
-- Returns nil when housing is disabled or misconfigured (the MDT then simply
-- reports zero properties instead of erroring).
local function getSchema()
    if schemaChecked then return resolvedSchema end
    schemaChecked = true
    resolvedSchema = nil

    local cfg = Config.Housing
    if type(cfg) ~= 'table' then return nil end   -- not configured -> silently off
    if cfg.enabled == false then return nil end   -- explicitly disabled -> silently off

    local preset = cfg.Presets and cfg.Presets[cfg.system]
    if type(preset) ~= 'table' then
        return disable(('Unknown housing system "%s"'):format(tostring(cfg.system)))
    end

    if not validIdent(preset.table) then
        return disable('The selected housing preset has a missing or invalid "table"')
    end

    local cols = preset.columns
    if type(cols) ~= 'table' or not validIdent(cols.owner) then
        return disable('The selected housing preset has a missing or invalid "columns.owner"')
    end

    -- Optional join (for two-table systems such as qb-houses).
    local join = nil
    if preset.join ~= nil then
        local j = preset.join
        if validIdent(j.table) and type(j.on) == 'table'
            and validIdent(j.on.left) and validIdent(j.on.right) then
            local jcols = {}
            if type(j.columns) == 'table' then
                for field, col in pairs(j.columns) do
                    if validIdent(col) then jcols[field] = col end
                end
            end
            join = { table = j.table, on = j.on, columns = jcols }
        else
            print('[ps-mdt] [housing] Invalid "join" definition in housing preset — ignoring join.')
        end
    end

    resolvedSchema = { table = preset.table, columns = cols, join = join }
    return resolvedSchema
end

-- Build a SELECT expression for one internal field, preferring a join-table
-- override when present. Returns the literal 'NULL' when the field isn't mapped
-- (e.g. a system that has no coords column).
local function fieldExpr(schema, field, mainAlias, joinAlias)
    if schema.join and schema.join.columns[field] then
        return joinAlias .. '.' .. qq(schema.join.columns[field])
    end
    local col = schema.columns[field]
    if validIdent(col) then
        return mainAlias .. '.' .. qq(col)
    end
    return 'NULL'
end

-- FROM `<table>` t [LEFT JOIN `<jointable>` j ON t.`left` = j.`right`]
local function fromClause(schema, mainAlias, joinAlias)
    local from = ('%s %s'):format(qq(schema.table), mainAlias)
    if schema.join then
        from = from .. (' LEFT JOIN %s %s ON %s.%s = %s.%s'):format(
            qq(schema.join.table), joinAlias,
            mainAlias, qq(schema.join.on.left),
            joinAlias, qq(schema.join.on.right)
        )
    end
    return from
end

-- Run a query, returning nil on error (handles a missing table gracefully).
local function safe(query, params)
    local ok, rows = pcall(MySQL.query.await, query, params)
    if not ok then
        if ps and ps.warn then ps.warn('[housing] Query failed: ' .. tostring(rows)) end
        return nil
    end
    return rows
end

--- Map of citizenid -> number of owned properties for the given citizenids.
--- @param citizenids string[]
--- @return table<string, number>
function Housing.GetCountsByOwners(citizenids)
    local counts = {}
    local schema = getSchema()
    if not schema or type(citizenids) ~= 'table' or #citizenids == 0 then
        return counts
    end

    local placeholders = {}
    for i = 1, #citizenids do placeholders[i] = '?' end
    local owner = qq(schema.columns.owner)

    -- Counts only need the ownership table; no join required.
    local sql = ('SELECT %s AS owner, COUNT(*) AS cnt FROM %s WHERE %s IN (%s) GROUP BY %s'):format(
        owner, qq(schema.table), owner, table.concat(placeholders, ','), owner
    )

    local rows = safe(sql, citizenids) or {}
    for _, row in ipairs(rows) do
        if row.owner ~= nil then
            counts[row.owner] = tonumber(row.cnt) or 0
        end
    end
    return counts
end

--- Properties owned by a citizen, each shaped as { id, property_name, coords,
--- keyholders } using the MDT's internal field names.
--- @param citizenid string
--- @return table[]
function Housing.GetByOwner(citizenid)
    local schema = getSchema()
    if not schema or not citizenid then return {} end

    local sql = ('SELECT %s AS id, %s AS property_name, %s AS coords, %s AS keyholders FROM %s WHERE %s.%s = ?'):format(
        fieldExpr(schema, 'id', 't', 'j'),
        fieldExpr(schema, 'name', 't', 'j'),
        fieldExpr(schema, 'coords', 't', 'j'),
        fieldExpr(schema, 'keyholders', 't', 'j'),
        fromClause(schema, 't', 'j'),
        't', qq(schema.columns.owner)
    )

    return safe(sql, { citizenid }) or {}
end

--- A single property by id, shaped as { id, property_name, coords, owner,
--- keyholders }, or nil when not found / not supported.
--- @param propertyId string|number
--- @return table|nil
function Housing.GetById(propertyId)
    local schema = getSchema()
    if not schema or propertyId == nil then return nil end

    -- Without an id column we cannot look a property up individually.
    if not validIdent(schema.columns.id) then return nil end

    local sql = ('SELECT %s AS id, %s AS property_name, %s AS coords, %s AS owner, %s AS keyholders FROM %s WHERE %s.%s = ? LIMIT 1'):format(
        fieldExpr(schema, 'id', 't', 'j'),
        fieldExpr(schema, 'name', 't', 'j'),
        fieldExpr(schema, 'coords', 't', 'j'),
        't.' .. qq(schema.columns.owner),
        fieldExpr(schema, 'keyholders', 't', 'j'),
        fromClause(schema, 't', 'j'),
        't', qq(schema.columns.id)
    )

    local ok, row = pcall(MySQL.single.await, sql, { propertyId })
    if not ok then
        if ps and ps.warn then ps.warn('[housing] GetById failed: ' .. tostring(row)) end
        return nil
    end
    return row
end
