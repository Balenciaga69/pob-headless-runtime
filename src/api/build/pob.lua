-- Adapter that centralizes direct access to PoB build/spec save-time state.
local M = {}
M.__index = M

function M.new()
    return setmetatable({}, M)
end

function M:prepare_for_save(build)
    if not build then
        return
    end

    if build.spec and build.spec.curClass and build.spec.curClass.classes then
        local ascendId = build.spec.curAscendClassId or 0
        local ascendClass = build.spec.curClass.classes[ascendId] or build.spec.curClass.classes[0]
        if ascendClass and ascendClass.name then
            build.spec.curAscendClassName = ascendClass.name
        end
    end
end

function M:save_build_xml(build, exportName)
    if not build or not build.SaveDB then
        return nil
    end
    return build:SaveDB(exportName)
end

return M
