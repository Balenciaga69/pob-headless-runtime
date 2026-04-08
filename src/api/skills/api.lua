-- Internal convenience facade for skill-related calls.
local M = {}

local function getSkillsService(session)
    local services = session and session:getServices() or nil
    return services and services.skills or nil
end

local function requireSkillsService(session)
    local service = getSkillsService(session)
    if not service then
        return nil, "skills service not available"
    end
    return service
end

function M.list_skills(session)
    local service, err = requireSkillsService(session)
    if not service then
        return nil, err
    end
    return service:list_skills()
end

function M.select_skill(session, params)
    local service, err = requireSkillsService(session)
    if not service then
        return nil, err
    end
    return service:select_skill(params)
end

function M.get_selected_skill(session)
    local service, err = requireSkillsService(session)
    if not service then
        return nil, err
    end
    return service:get_selected_skill()
end

function M.restore_skill_selection(session, snapshot)
    local service, err = requireSkillsService(session)
    if not service then
        return nil, err
    end
    return service:restore_skill_selection(snapshot)
end

return M
