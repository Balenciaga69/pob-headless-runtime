-- Internal convenience facade for build-related calls.
local M = {}

-- Internal convenience facade. The formal public API is `api.init`.

local function getBuildService(session)
    -- Look up the build service from the bound session.
    local services = session and session:getServices() or nil
    return services and services.build or nil
end

local function requireBuildService(session)
    -- Fail fast when the build service is not available.
    local service = getBuildService(session)
    if not service then
        return nil, "build service not available"
    end
    return service
end

function M.load_build_xml(session, xmlText, name)
    -- Load a build from raw XML text.
    local service, err = requireBuildService(session)
    if not service then
        return nil, err
    end
    return service:load_build_xml(xmlText, name)
end

function M.load_build_code(session, code, name)
    -- Load a build from a PoB import code.
    local service, err = requireBuildService(session)
    if not service then
        return nil, err
    end
    return service:load_build_code(code, name)
end

function M.load_build_file(session, path)
    -- Load a build from a file on disk.
    local service, err = requireBuildService(session)
    if not service then
        return nil, err
    end
    return service:load_build_file(path)
end

function M.save_build_xml(session)
    -- Save the current build as XML text.
    local service, err = requireBuildService(session)
    if not service then
        return nil, err
    end
    return service:save_build_xml()
end

function M.save_build_code(session)
    -- Save the current build as a PoB import code.
    local service, err = requireBuildService(session)
    if not service then
        return nil, err
    end
    return service:save_build_code()
end

function M.save_build_file(session, path)
    -- Save the current build to a file on disk.
    local service, err = requireBuildService(session)
    if not service then
        return nil, err
    end
    return service:save_build_file(path)
end

function M.update_imported_build(session, params)
    -- Refresh an imported build using the provided parameters.
    local service, err = requireBuildService(session)
    if not service then
        return nil, err
    end
    return service:update_imported_build(params)
end

return M
