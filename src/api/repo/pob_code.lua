-- PoB build code codec helpers.
local M = {}

local BASE64_ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local BASE64_ENCODE = {}
local BASE64_DECODE = {}

for index = 1, #BASE64_ALPHABET do
	local ch = BASE64_ALPHABET:sub(index, index)
	BASE64_ENCODE[index - 1] = ch
	BASE64_DECODE[ch:byte()] = index - 1
end

local function trim(text)
	return (text or ""):match("^%s*(.-)%s*$")
end

local function html_unescape(text)
	text = text:gsub("&amp;", "&")
	text = text:gsub("&lt;", "<")
	text = text:gsub("&gt;", ">")
	text = text:gsub("&quot;", '"')
	text = text:gsub("&#39;", "'")
	text = text:gsub("&#x([%x]+);", function(hex)
		return string.char(tonumber(hex, 16) or 0)
	end)
	text = text:gsub("&#([0-9]+);", function(dec)
		return string.char(tonumber(dec, 10) or 0)
	end)
	return text
end

local function url_decode(text)
	return (text:gsub("+", " "):gsub("%%(%x%x)", function(hex)
		return string.char(tonumber(hex, 16) or 0)
	end))
end

local function split_url(text)
	local fragmentStart = text:find("#", 1, true)
	if fragmentStart then
		text = text:sub(1, fragmentStart - 1)
	end

	local queryStart = text:find("?", 1, true)
	if queryStart then
		return text:sub(1, queryStart - 1), text:sub(queryStart + 1)
	end

	return text, nil
end

local function parse_query(queryText)
	local result = {}
	for pair in queryText:gmatch("[^&]+") do
		local key, value = pair:match("^([^=]*)=(.*)$")
		if key then
			key = url_decode(key):lower()
			value = url_decode(value or "")
			result[key] = result[key] or value
		end
	end
	return result
end

local function is_url(text)
	return text:match("^%a[%w+%.%-]*://") ~= nil or text:match("^pob:[/\\]") ~= nil
end

function M.extract_payload(text)
	text = html_unescape(trim(text))
	if text == "" then
		return ""
	end

	if not is_url(text) then
		return text
	end

	local path, queryText = split_url(text)
	if queryText then
		local query = parse_query(queryText)
		for _, key in ipairs({ "data", "code", "i", "v" }) do
			local value = query[key]
			if value and value ~= "" then
				return value
			end
		end
	end

	local payload = path:match("([^/\\]+)$")
	return payload or text
end

function M.normalize_base64url(text)
	text = trim(text):gsub("%s+", "")
	text = text:gsub("-", "+"):gsub("_", "/")
	text = text .. string.rep("=", (-#text) % 4)
	return text
end

local function base64_encode(data)
	if type(data) ~= "string" then
		return nil, "data is required"
	end
	if data == "" then
		return ""
	end

	local out = {}
	local len = #data
	for index = 1, len, 3 do
		local a, b, c = data:byte(index, index + 2)
		local n = a * 65536 + (b or 0) * 256 + (c or 0)
		local c1 = math.floor(n / 262144) % 64
		local c2 = math.floor(n / 4096) % 64
		local c3 = math.floor(n / 64) % 64
		local c4 = n % 64

		out[#out + 1] = BASE64_ENCODE[c1]
		out[#out + 1] = BASE64_ENCODE[c2]
		if b then
			out[#out + 1] = BASE64_ENCODE[c3]
		else
			out[#out + 1] = "="
		end
		if c then
			out[#out + 1] = BASE64_ENCODE[c4]
		else
			out[#out + 1] = "="
		end
	end

	return table.concat(out)
end

local function base64_decode(data)
	if type(data) ~= "string" then
		return nil, "invalid base64 payload"
	end
	data = data:gsub("%s+", "")
	if data == "" then
		return "", nil
	end
	if (#data % 4) ~= 0 then
		return nil, "invalid base64 payload"
	end

	local out = {}
	for index = 1, #data, 4 do
		local c1, c2, c3, c4 = data:byte(index, index + 3)
		local v1 = BASE64_DECODE[c1]
		local v2 = BASE64_DECODE[c2]
		if not v1 or not v2 then
			return nil, "invalid base64 payload"
		end

		local pad3 = c3 == string.byte("=")
		local pad4 = c4 == string.byte("=")
		if pad3 and not pad4 then
			return nil, "invalid base64 payload"
		end

		if pad3 then
			local n = v1 * 262144 + v2 * 4096
			out[#out + 1] = string.char(math.floor(n / 65536) % 256)
		else
			local v3 = BASE64_DECODE[c3]
			if not v3 then
				return nil, "invalid base64 payload"
			end
			if pad4 then
				local n = v1 * 262144 + v2 * 4096 + v3 * 64
				out[#out + 1] = string.char(
					math.floor(n / 65536) % 256,
					math.floor(n / 256) % 256
				)
			else
				local v4 = BASE64_DECODE[c4]
				if not v4 then
					return nil, "invalid base64 payload"
				end
				local n = v1 * 262144 + v2 * 4096 + v3 * 64 + v4
				out[#out + 1] = string.char(
					math.floor(n / 65536) % 256,
					math.floor(n / 256) % 256,
					n % 256
				)
			end
		end
	end

	return table.concat(out)
end

local ffi_ok, ffi = pcall(require, "ffi")
local zlib_lib
local zlib_load_err

if ffi_ok then
	ffi.cdef([[
		typedef unsigned char Bytef;
		typedef unsigned int uInt;
		typedef unsigned long uLong;
		typedef unsigned long uLongf;
		typedef void *voidpf;
		typedef void *voidp;
		typedef struct z_stream_s {
			Bytef *next_in;
			uInt avail_in;
			uLong total_in;
			Bytef *next_out;
			uInt avail_out;
			uLong total_out;
			char *msg;
			void *state;
			voidpf zalloc;
			voidpf zfree;
			voidp opaque;
			int data_type;
			uLong adler;
			uLong reserved;
		} z_stream;
		const char * zlibVersion(void);
		int compress2(Bytef *dest, uLongf *destLen, const Bytef *source, uLong sourceLen, int level);
		uLong compressBound(uLong sourceLen);
		int inflateInit2_(z_stream *strm, int windowBits, const char *version, int stream_size);
		int inflate(z_stream *strm, int flush);
		int inflateEnd(z_stream *strm);
	]])
end

local function path_exists(path)
	local file = io.open(path, "rb")
	if file then
		file:close()
		return true
	end
	return false
end

local function join_path(...)
	local parts = { ... }
	local sep = package.config:sub(1, 1)
	local filtered = {}
	for i = 1, #parts do
		local part = parts[i]
		if part ~= nil and part ~= "" then
			filtered[#filtered + 1] = tostring(part)
		end
	end
	if #filtered == 0 then
		return ""
	end
	local result = filtered[1]:gsub("[/\\]+$", "")
	for i = 2, #filtered do
		local part = filtered[i]:gsub("^[/\\]+", "")
		result = result:gsub("[/\\]+$", "") .. sep .. part
	end
	return result
end

local function candidate_paths()
	local paths = {}
	if type(GetRuntimePath) == "function" then
		local runtimePath = GetRuntimePath()
		if type(runtimePath) == "string" and runtimePath ~= "" then
			paths[#paths + 1] = join_path(runtimePath, "zlib1.dll")
		end
	end
	paths[#paths + 1] = join_path("runtime", "zlib1.dll")
	paths[#paths + 1] = join_path("..", "runtime", "zlib1.dll")
	paths[#paths + 1] = "zlib1.dll"
	return paths
end

local function load_zlib()
	if not ffi_ok then
		return nil, "LuaJIT FFI is required for PoB code compression"
	end
	if zlib_lib then
		return zlib_lib
	end
	if zlib_load_err then
		return nil, zlib_load_err
	end

	for _, path in ipairs(candidate_paths()) do
		if path_exists(path) then
			local ok, lib = pcall(ffi.load, path)
			if ok then
				zlib_lib = lib
				return zlib_lib
			end
			zlib_load_err = tostring(lib)
		end
	end

	if not zlib_load_err then
		zlib_load_err = "zlib1.dll not found"
	end
	return nil, zlib_load_err
end

local Z_OK = 0
local Z_STREAM_END = 1
local Z_BUF_ERROR = -5
local Z_DEFAULT_COMPRESSION = -1
local Z_DEFLATED = 8
local Z_DEFAULT_STRATEGY = 0
local Z_NO_FLUSH = 0

local function compress_raw(data)
	if type(data) ~= "string" then
		return nil, "xmlText is required"
	end
	if data == "" then
		return ""
	end

	local zlib, err = load_zlib()
	if not zlib then
		return nil, err
	end

	local sourceLen = #data
	local source = ffi.new("Bytef[?]", sourceLen)
	ffi.copy(source, data, sourceLen)

	local destLen = ffi.new("uLongf[1]", tonumber(zlib.compressBound(sourceLen)))
	local dest = ffi.new("Bytef[?]", destLen[0])
	local ret = zlib.compress2(dest, destLen, source, sourceLen, 9)
	if ret ~= Z_OK then
		return nil, "failed to compress PoB code"
	end

	return ffi.string(dest, destLen[0])
end

local function inflate_with_window_bits(rawData, windowBits)
	local zlib, err = load_zlib()
	if not zlib then
		return nil, err
	end

	local sourceLen = #rawData
	local source = ffi.new("Bytef[?]", sourceLen)
	ffi.copy(source, rawData, sourceLen)

	local stream = ffi.new("z_stream[1]")
	stream[0].next_in = source
	stream[0].avail_in = sourceLen
	stream[0].zalloc = nil
	stream[0].zfree = nil
	stream[0].opaque = nil

	local version = zlib.zlibVersion()
	local ret = zlib.inflateInit2_(stream, windowBits, version, ffi.sizeof("z_stream"))
	if ret ~= Z_OK then
		return nil, "unable to decode PoB code"
	end

	local output = {}
	local chunkSize = 16384
	local chunk = ffi.new("Bytef[?]", chunkSize)

	while true do
		stream[0].next_out = chunk
		stream[0].avail_out = chunkSize
		ret = zlib.inflate(stream, Z_NO_FLUSH)

		local produced = chunkSize - stream[0].avail_out
		if produced > 0 then
			output[#output + 1] = ffi.string(chunk, produced)
		end

		if ret == Z_STREAM_END then
			break
		end
		if ret ~= Z_OK then
			zlib.inflateEnd(stream)
			return nil, "unable to decode PoB code"
		end
	end

	zlib.inflateEnd(stream)
	return table.concat(output)
end

local function decompress_raw(data)
	if type(data) ~= "string" then
		return nil, "invalid base64 payload"
	end
	if data == "" then
		return ""
	end

	local variants = { -15, 15, 47 }
	for _, windowBits in ipairs(variants) do
		local xmlText = inflate_with_window_bits(data, windowBits)
		if xmlText then
			return xmlText
		end
	end

	return nil, "unable to decode PoB code"
end

function M.compress_raw(xmlText)
	return compress_raw(xmlText)
end

function M.decompress_raw(rawData)
	return decompress_raw(rawData)
end

function M.decode_to_xml(code)
	if type(code) ~= "string" or trim(code) == "" then
		return nil, "code is required"
	end

	local payload = M.extract_payload(code)
	payload = M.normalize_base64url(payload)

	local rawData, decodeErr = base64_decode(payload)
	if not rawData then
		return nil, decodeErr
	end

	local xmlText, inflateErr = decompress_raw(rawData)
	if not xmlText then
		return nil, inflateErr
	end

	return xmlText
end

function M.encode_xml(xmlText)
	if type(xmlText) ~= "string" or trim(xmlText) == "" then
		return nil, "xmlText is required"
	end

	local compressed, err = compress_raw(xmlText)
	if not compressed then
		return nil, err
	end

	local encoded, encodeErr = base64_encode(compressed)
	if not encoded then
		return nil, encodeErr
	end

	return (encoded:gsub("+", "-"):gsub("/", "_"))
end

return M
