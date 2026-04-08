local pobCode = require("api.repo.pob_code")
local expect = require("testkit").expect

do
	local payload = pobCode.extract_payload("https://example.invalid/pob/build?code=abc123")
	expect(payload == "abc123", "expected code query parameter to be extracted")
end

do
	local payload = pobCode.extract_payload("https://example.invalid/pob/build/abc123")
	expect(payload == "abc123", "expected last path segment to be extracted")
end

do
	local normalized = pobCode.normalize_base64url("a-b_c")
	expect(normalized == "a+b/c===", "expected base64url normalization")
end

do
	local xmlText = "<PathOfBuilding><Build targetVersion=\"3.24\"></Build></PathOfBuilding>"
	local code, err = pobCode.encode_xml(xmlText)
	expect(code ~= nil and err == nil, "expected xml to encode")
	expect(type(code) == "string" and #code > 0, "expected non-empty code")

	local decoded, decodeErr = pobCode.decode_to_xml(code)
	expect(decoded == xmlText, "expected encoded xml to roundtrip")
	expect(decodeErr == nil, "expected roundtrip decode to succeed")
end

do
	local decoded, err = pobCode.decode_to_xml("$$$")
	expect(decoded == nil, "expected invalid code to fail")
	expect(err == "invalid base64 payload", "expected invalid base64 payload error")
end
