local M = {}

function M.parse_expected_build_state(xmlText)
    if not common or not common.xml or type(common.xml.ParseXML) ~= "function" then
        return nil, "xml parser is unavailable"
    end

    local dbXML, errMsg = common.xml.ParseXML(xmlText)
    if errMsg then
        return nil, errMsg
    end
    if type(dbXML) ~= "table" or type(dbXML[1]) ~= "table" then
        return nil, "invalid build xml: root element missing"
    end
    if dbXML[1].elem ~= "PathOfBuilding" then
        return nil, "invalid build xml: PathOfBuilding root element missing"
    end

    local sectionCount = 0
    local buildNode
    for _, node in ipairs(dbXML[1]) do
        if type(node) == "table" then
            sectionCount = sectionCount + 1
            if node.elem == "Build" and not buildNode then
                buildNode = node
            end
        end
    end

    if not buildNode then
        return nil, "invalid build xml: Build section missing"
    end

    local attrib = buildNode.attrib or {}
    return {
        sectionCount = sectionCount,
        level = tonumber(attrib.level),
        className = attrib.className,
        ascendClassName = attrib.ascendClassName,
        targetVersion = attrib.targetVersion,
    }, nil
end

function M.capture_loaded_build_state(build)
    local spec = build and build.spec or nil
    local groups = build and build.skillsTab and build.skillsTab.socketGroupList or nil
    return {
        sectionCount = build and build.xmlSectionList and #build.xmlSectionList or 0,
        level = build and tonumber(build.characterLevel) or nil,
        className = spec and spec.curClassName or nil,
        ascendClassName = spec and spec.curAscendClassName or nil,
        targetVersion = build and (build.targetVersion or (spec and spec.treeVersion) or nil) or nil,
        mainSocketGroup = build and tonumber(build.mainSocketGroup) or nil,
        socketGroupCount = type(groups) == "table" and #groups or 0,
    }
end

function M.is_default_like_loaded_state(state)
    return state.sectionCount <= 1
        and state.level == 1
        and state.className == "Scion"
        and state.ascendClassName == "None"
        and state.targetVersion == "3_0"
        and (state.socketGroupCount or 0) <= 1
end

function M.validate_loaded_build(build, expectedState)
    if not build then
        return nil, "build not initialized"
    end

    local actualState = M.capture_loaded_build_state(build)
    if actualState.sectionCount == 0 then
        return nil, "build load did not populate any xml sections"
    end
    if
        expectedState
        and expectedState.sectionCount
        and actualState.sectionCount < expectedState.sectionCount
    then
        return nil,
            string.format(
                "build load was incomplete: expected at least %d xml sections, got %d",
                expectedState.sectionCount,
                actualState.sectionCount
            )
    end
    if expectedState and expectedState.level and actualState.level ~= expectedState.level then
        return nil,
            string.format(
                "build load mismatch: expected level %d, got %s",
                expectedState.level,
                tostring(actualState.level)
            )
    end
    if
        expectedState
        and type(expectedState.className) == "string"
        and expectedState.className ~= ""
        and actualState.className ~= expectedState.className
    then
        return nil,
            string.format(
                "build load mismatch: expected class %s, got %s",
                expectedState.className,
                tostring(actualState.className)
            )
    end
    if
        expectedState
        and type(expectedState.ascendClassName) == "string"
        and expectedState.ascendClassName ~= ""
        and actualState.ascendClassName ~= expectedState.ascendClassName
    then
        return nil,
            string.format(
                "build load mismatch: expected ascendancy %s, got %s",
                expectedState.ascendClassName,
                tostring(actualState.ascendClassName)
            )
    end
    if
        expectedState
        and type(expectedState.targetVersion) == "string"
        and expectedState.targetVersion ~= ""
        and actualState.targetVersion ~= expectedState.targetVersion
    then
        return nil,
            string.format(
                "build load mismatch: expected tree version %s, got %s",
                expectedState.targetVersion,
                tostring(actualState.targetVersion)
            )
    end
    if M.is_default_like_loaded_state(actualState) then
        return nil,
            "build load left the runtime at the default empty build state; the build was not applied"
    end

    return build
end

return M
