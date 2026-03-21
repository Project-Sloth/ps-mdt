-- CREDITS
-- https://github.com/citizenfx/lua/blob/luaglm-dev/cfx/libs/scripts/examples/dataview.lua
-- DemiAutomatic: https://github.com/DemiAutomatic


local dataView = setmetatable({
    EndBig = ">",
    EndLittle = "<",
    Types = {
        Int8 = { code = "i1" },
        Uint8 = { code = "I1" },
        Int16 = { code = "i2" },
        Uint16 = { code = "I2" },
        Int32 = { code = "i4" },
        Uint32 = { code = "I4" },
        Int64 = { code = "i8" },
        Uint64 = { code = "I8" },
        Float32 = { code = "f", size = 4 }, -- a float (native size)
        Float64 = { code = "d", size = 8 }, -- a double (native size)

        LuaInt = { code = "j" }, -- a lua_Integer
        UluaInt = { code = "J" }, -- a lua_Unsigned
        LuaNum = { code = "n" }, -- a lua_Number
        String = { code = "z", size = -1, }, -- zero terminated string
    },

    FixedTypes = {
        String = { code = "c" }, -- a fixed-sized string with n bytes
        Int = { code = "i" }, -- a signed int with n bytes
        Uint = { code = "I" }, -- an unsigned int with n bytes
    },
}, {
    __call = function(_, length)
        return dataView.ArrayBuffer(length)
    end
})
dataView.__index = dataView

--[[ Create an ArrayBuffer with a size in bytes --]]
function dataView.ArrayBuffer(length)
    return setmetatable({
        blob = string.blob(length),
        length = length,
        offset = 1,
        cangrow = true,
    }, dataView)
end

--[[ Wrap a non-internalized string --]]
function dataView.Wrap(blob)
    return setmetatable({
        blob = blob,
        length = blob:len(),
        offset = 1,
        cangrow = true,
    }, dataView)
end

--[[ Return the underlying bytebuffer --]]
function dataView:Buffer() return self.blob end
function dataView:ByteLength() return self.length end
function dataView:ByteOffset() return self.offset end
function dataView:SubView(offset, length)
    return setmetatable({
        blob = self.blob,
        length = length or self.length,
        offset = 1 + offset,
        cangrow = false,
    }, dataView)
end

--[[ Return the Endianness format character --]]
local function ef(big) return (big and dataView.EndBig) or dataView.EndLittle end

--[[ Helper function for setting fixed datatypes within a buffer --]]
local function packblob(self, offset, value, code)
    -- If cangrow is false the dataview represents a subview, i.e., a subset
    -- of some other string view. Ensure the references are the same before
    -- updating the subview
    local packed = self.blob:blob_pack(offset, code, value)
    if self.cangrow or packed == self.blob then
        self.blob = packed
        self.length = packed:len()
        return true
    else
        return false
    end
end

--[[
    Create the API by using dataView.Types
--]]
for label,datatype in pairs(dataView.Types) do
    if not datatype.size then  -- cache fixed encoding size
        datatype.size = string.packsize(datatype.code)
    elseif datatype.size >= 0 and string.packsize(datatype.code) ~= datatype.size then
        local msg = "Pack size of %s (%d) does not match cached length: (%d)"
        error(msg:format(label, string.packsize(datatype.code), datatype.size))
        return nil
    end

    dataView["Get" .. label] = function(self, offset, endian)
        offset = offset or 0
        if offset >= 0 then
            local o = self.offset + offset
            local v,_ = self.blob:blob_unpack(o, ef(endian) .. datatype.code)
            return v
        end
        return nil
    end

    dataView["Set" .. label] = function(self, offset, value, endian)
        if offset >= 0 and value then
            local o = self.offset + offset
            local v_size = (datatype.size < 0 and value:len()) or datatype.size
            if self.cangrow or ((o + (v_size - 1)) <= self.length) then
                if not packblob(self, o, value, ef(endian) .. datatype.code) then
                    error("cannot grow subview")
                end
            else
                error("cannot grow dataview")
            end
        end
        return self
    end
end

for label,datatype in pairs(dataView.FixedTypes) do
    datatype.size = -1 -- Ensure cached encoding size is invalidated

    dataView["GetFixed" .. label] = function(self, offset, typelen, endian)
        if offset >= 0 then
            local o = self.offset + offset
            if (o + (typelen - 1)) <= self.length then
                local code = ef(endian) .. "c" .. tostring(typelen)
                local v,_ = self.blob:blob_unpack(o, code)
                return v
            end
        end
        return nil -- Out of bounds
    end

    dataView["SetFixed" .. label] = function(self, offset, typelen, value, endian)
        if offset >= 0 and value then
            local o = self.offset + offset
            if self.cangrow or ((o + (typelen - 1)) <= self.length) then
                local code = ef(endian) .. "c" .. tostring(typelen)
                if not packblob(self, o, value, code) then
                    error("cannot grow subview")
                end
            else
                error("cannot grow dataview")
            end
        end
        return self
    end
end

return dataView