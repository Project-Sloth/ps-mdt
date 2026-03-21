Cache = Cache or {}

Cache.store = Cache.store or {}
Cache.pending = Cache.pending or {}

function Cache.get(key)
    if not key then
        return nil
    end

    local entry = Cache.store[key]
    if not entry then
        return nil
    end

    if entry.expiresAt and entry.expiresAt < os.time() then
        Cache.store[key] = nil
        return nil
    end

    return entry.value
end

function Cache.set(key, value, ttlSeconds)
    if not key then
        return value
    end

    local expiresAt = nil
    if ttlSeconds and tonumber(ttlSeconds) then
        expiresAt = os.time() + math.max(0, math.floor(tonumber(ttlSeconds)))
    end

    Cache.store[key] = {
        value = value,
        expiresAt = expiresAt
    }

    return value
end

function Cache.getOrSet(key, ttlSeconds, fetcher)
    if not fetcher then
        return Cache.get(key)
    end

    local cached = Cache.get(key)
    if cached ~= nil then
        return cached
    end

    if Cache.pending[key] then
        return Citizen.Await(Cache.pending[key])
    end

    local promiseRef = promise.new()
    Cache.pending[key] = promiseRef

    CreateThread(function()
        local ok, result = pcall(fetcher)
        if ok then
            Cache.set(key, result, ttlSeconds)
            promiseRef:resolve(result)
        else
            promiseRef:resolve(nil)
        end
        Cache.pending[key] = nil
    end)

    return Citizen.Await(promiseRef)
end

function Cache.invalidate(key)
    if not key then
        return
    end
    Cache.store[key] = nil
end

function Cache.invalidatePrefix(prefix)
    if not prefix then
        return
    end
    for key in pairs(Cache.store) do
        if type(key) == 'string' and key:sub(1, #prefix) == prefix then
            Cache.store[key] = nil
        end
    end
end
