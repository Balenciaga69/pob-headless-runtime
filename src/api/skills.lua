-- Internal convenience facade for skill-related calls.
local M = {}

-- Internal convenience facade. The formal public API is `api.init`.

-- Retrieves the skills service from the session, or returns nil if not available.
local function getSkillsService(session)
    -- Resolve the skills service from the session.
    local services = session and session:getServices() or nil
    return services and services.skills or nil
end

-- Requires the skills service to be available, returning an error if not.
local function requireSkillsService(session)
    -- Fail fast when the skills service is missing.
    local service = getSkillsService(session)
    if not service then
        return nil, "skills service not available"
    end
    return service
end

-- Lists all available skills for the given session.
function M.list_skills(session)
    -- Return every available skill option.
    local service, err = requireSkillsService(session)
    if not service then
        return nil, err
    end
    return service:list_skills()
end

-- Selects a skill for the given session based on the provided parameters.
function M.select_skill(session, params)
    -- Apply a new skill selection.
    local service, err = requireSkillsService(session)
    if not service then
        return nil, err
    end
    return service:select_skill(params)
end

-- Retrieves the currently selected skill for the session.
function M.get_selected_skill(session)
    -- Return the current skill selection.
    local service, err = requireSkillsService(session)
    if not service then
        return nil, err
    end
    return service:get_selected_skill()
end

-- Restores the skill selection for the session from a given snapshot.
function M.restore_skill_selection(session, snapshot)
    -- Restore the previously saved skill selection.
    local service, err = requireSkillsService(session)
    if not service then
        return nil, err
    end
    return service:restore_skill_selection(snapshot)
end

return M
