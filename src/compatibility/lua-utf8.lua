-- Compatibility shim for environments without a native utf8 module.
local bit = bit
local error = error
local ipairs = ipairs
local rawget = rawget
local string = string
local table = table
local unpack = unpack
local _G = _G

module("utf8")

charpattern = "[%z\x01-\x7F\xC2-\xF4][\x80-\xBF]*"

local function strRelToAbs(str, ...)
    -- Convert relative string indexes into absolute offsets.
    local args = { ... }
    for k, v in ipairs(args) do
        v = v > 0 and v or #str + v + 1
        if v < 1 or v > #str then
            error("bad index to string (out of range)", 3)
        end
        args[k] = v
    end
    return unpack(args)
end

local function decode(str, startPos)
    -- Decode a UTF-8 sequence starting at the requested position.
    startPos = strRelToAbs(str, startPos or 1)
    local b1 = str:byte(startPos, startPos)
    if b1 < 0x80 then
        return startPos, startPos
    end
    if b1 > 0xF4 or b1 < 0xC2 then
        return nil
    end
    local contByteCount = b1 >= 0xF0 and 3 or b1 >= 0xE0 and 2 or b1 >= 0xC0 and 1
    local endPos = startPos + contByteCount
    for _, bX in ipairs({ str:byte(startPos + 1, endPos) }) do
        if bit.band(bX, 0xC0) ~= 0x80 then
            return nil
        end
    end
    return startPos, endPos
end

function char(...)
    -- Encode codepoints into a UTF-8 string.
    local buf = {}
    for k, v in ipairs({ ... }) do
        if v < 0 or v > 0x10FFFF then
            error("bad argument #" .. k .. " to char (out of range)", 2)
        end
        local b1, b2, b3, b4
        if v < 0x80 then
            table.insert(buf, string.char(v))
        elseif v < 0x800 then
            b1 = bit.bor(0xC0, bit.band(bit.rshift(v, 6), 0x1F))
            b2 = bit.bor(0x80, bit.band(v, 0x3F))
            table.insert(buf, string.char(b1, b2))
        elseif v < 0x10000 then
            b1 = bit.bor(0xE0, bit.band(bit.rshift(v, 12), 0x0F))
            b2 = bit.bor(0x80, bit.band(bit.rshift(v, 6), 0x3F))
            b3 = bit.bor(0x80, bit.band(v, 0x3F))
            table.insert(buf, string.char(b1, b2, b3))
        else
            b1 = bit.bor(0xF0, bit.band(bit.rshift(v, 18), 0x07))
            b2 = bit.bor(0x80, bit.band(bit.rshift(v, 12), 0x3F))
            b3 = bit.bor(0x80, bit.band(bit.rshift(v, 6), 0x3F))
            b4 = bit.bor(0x80, bit.band(v, 0x3F))
            table.insert(buf, string.char(b1, b2, b3, b4))
        end
    end
    return table.concat(buf, "")
end

function codes(str)
    -- Iterate over UTF-8 codepoints as start position and substring pairs.
    local i = 1
    return function()
        if i > #str then
            return nil
        end
        local startPos, endPos = decode(str, i)
        if not startPos then
            error("invalid UTF-8 code", 2)
        end
        i = endPos + 1
        return startPos, str:sub(startPos, endPos)
    end
end

function codepoint(str, startPos, endPos)
    -- Return the numeric codepoints in the requested range.
    startPos, endPos = strRelToAbs(str, startPos or 1, endPos or startPos or 1)
    local ret = {}
    repeat
        local seqStartPos, seqEndPos = decode(str, startPos)
        if not seqStartPos then
            error("invalid UTF-8 code", 2)
        end
        startPos = seqEndPos + 1
        local len = seqEndPos - seqStartPos + 1
        if len == 1 then
            table.insert(ret, str:byte(seqStartPos))
        else
            local b1 = str:byte(seqStartPos)
            local cp = 0
            for i = seqStartPos + 1, seqEndPos do
                local bX = str:byte(i)
                cp = bit.bor(bit.lshift(cp, 6), bit.band(bX, 0x3F))
                b1 = bit.lshift(b1, 1)
            end
            cp = bit.bor(cp, bit.lshift(bit.band(b1, 0x7F), (len - 1) * 5))
            table.insert(ret, cp)
        end
    until seqEndPos >= endPos
    return unpack(ret)
end

function len(str, startPos, endPos)
    -- Count UTF-8 codepoints in the requested range.
    startPos, endPos = strRelToAbs(str, startPos or 1, endPos or -1)
    local count = 0
    repeat
        local seqStartPos, seqEndPos = decode(str, startPos)
        if not seqStartPos then
            return false, startPos
        end
        startPos = seqEndPos + 1
        count = count + 1
    until seqEndPos >= endPos
    return count
end

function offset(str, n, startPos)
    -- Find the byte offset of the n-th codepoint from a start position.
    startPos = strRelToAbs(str, startPos or (n >= 0 and 1) or #str)
    if n == 0 then
        for i = startPos, 1, -1 do
            local seqStartPos = decode(str, i)
            if seqStartPos then
                return seqStartPos
            end
        end
        return nil
    end
    if not decode(str, startPos) then
        error("initial position is not beginning of a valid sequence", 2)
    end
    local itStart, itEnd, itStep
    if n > 0 then
        itStart = startPos
        itEnd = #str
        itStep = 1
    else
        n = -n
        itStart = startPos
        itEnd = 1
        itStep = -1
    end
    for i = itStart, itEnd, itStep do
        local seqStartPos = decode(str, i)
        if seqStartPos then
            n = n - 1
            if n == 0 then
                return seqStartPos
            end
        end
    end
    return nil
end

function force(str)
    -- Replace invalid byte sequences with the Unicode replacement character.
    local buf = {}
    local curPos, endPos = 1, #str
    repeat
        local seqStartPos, seqEndPos = decode(str, curPos)
        if not seqStartPos then
            table.insert(buf, char(0xFFFD))
            curPos = curPos + 1
        else
            table.insert(buf, str:sub(seqStartPos, seqEndPos))
            curPos = seqEndPos + 1
        end
    until curPos > endPos
    return table.concat(buf, "")
end

function sub(str, i, j)
    -- Delegate to string.sub for compatibility.
    return string.sub(str, i, j)
end

function find(str, pattern, init, plain)
    -- Delegate to string.find for compatibility.
    return string.find(str, pattern, init, plain and true or false)
end

function gsub(str, pattern, repl, n)
    -- Delegate to string.gsub for compatibility.
    return string.gsub(str, pattern, repl, n)
end

function match(str, pattern, init)
    -- Delegate to string.match for compatibility.
    return string.match(str, pattern, init)
end

function reverse(str)
    -- Reverse a UTF-8 string by codepoint.
    local buf = {}
    for _, ch in codes(str) do
        table.insert(buf, 1, ch)
    end
    return table.concat(buf, "")
end

local function findNextStart(str, pos)
    -- Find the next valid codepoint boundary after a byte position.
    local i = 1
    while i <= #str do
        if i > pos then
            return i
        end
        local _, endPos = decode(str, i)
        i = endPos + 1
    end
    return nil
end

local function findPrevStart(str, pos)
    -- Find the previous valid codepoint boundary before a byte position.
    local prev = nil
    local i = 1
    while i <= #str do
        if i >= pos then
            return prev
        end
        prev = i
        local _, endPos = decode(str, i)
        i = endPos + 1
    end
    return prev
end

function next(str, pos, dir)
    -- Walk to the next or previous UTF-8 codepoint boundary.
    dir = dir or 1
    if dir >= 0 then
        if not pos or pos < 1 then
            pos = 1
        end
        if pos > #str then
            return nil
        end
        return findNextStart(str, pos)
    end
    if not pos or pos <= 1 then
        return nil
    end
    return findPrevStart(str, pos)
end

local loadedPackage = rawget(_G, "package")
local utf8Module = (loadedPackage and loadedPackage.loaded and loadedPackage.loaded["utf8"])
    or rawget(_G, "utf8")
if loadedPackage and loadedPackage.loaded then
    loadedPackage.loaded["utf8"] = utf8Module
    loadedPackage.loaded["lua-utf8"] = utf8Module
end

return utf8Module
