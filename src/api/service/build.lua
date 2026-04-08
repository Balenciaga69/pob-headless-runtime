-- Build service orchestrating load and save use cases.
local M = {}
M.__index = M
local pobCode = require("api.repo.pob_code")

function M.new(repos, services, session, fileUtil)
    -- Keep the build service stateless by storing only its dependencies.
    return setmetatable({
        repos = repos,
        services = services,
        session = session,
        fileUtil = fileUtil,
    }, M)
end

function M:load_build_xml(xmlText, name)
    -- Load a build from XML text through the repo adapter.
    return self.repos.build.loadBuildXml(self.session, xmlText, name)
end

function M:load_build_file(path)
    -- Load a build from disk using the shared file helper.
    return self.repos.build.loadBuildFile(self.session, path, self.fileUtil.readAll)
end

function M:save_build_xml()
    -- Serialize the current build back into XML text.
    return self.repos.build.saveBuildXml(self.session)
end

function M:load_build_code(code, name)
    -- Decode a PoB import code and delegate to the XML loader.
    if type(code) ~= "string" or code == "" then
        return nil, "code is required"
    end

    local xmlText, err = pobCode.decode_to_xml(code)
    if not xmlText then
        return nil, err
    end

    return self:load_build_xml(xmlText, name)
end

function M:save_build_code()
    -- Serialize the current build and encode it as a PoB import code.
    local xmlText, err = self:save_build_xml()
    if not xmlText then
        return nil, err
    end

    local code, encodeErr = pobCode.encode_xml(xmlText)
    if not code then
        return nil, encodeErr
    end

    return code
end

function M:save_build_file(path)
    -- Write the current build to disk.
    return self.repos.build.saveBuildFile(self.session, path, self.fileUtil.writeAll)
end

function M:update_imported_build(params)
    -- Delegate imported-build refreshes to the importer service.
    return self.services.importer:update_imported_build(params)
end

return M
