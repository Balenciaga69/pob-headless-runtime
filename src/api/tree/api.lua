-- Internal convenience facade for tree-related calls.
local M = {}

local function getTreeService(session)
    local services = session and session:getServices() or nil
    return services and services.tree or nil
end

local function requireTreeService(session)
    local service = getTreeService(session)
    if not service then
        return nil, "tree service not available"
    end
    return service
end

function M.get_tree(session)
    local service, err = requireTreeService(session)
    if not service then
        return nil, err
    end
    return service:get_tree()
end

function M.get_tree_node(session, nodeId)
    local service, err = requireTreeService(session)
    if not service then
        return nil, err
    end
    return service:get_tree_node(nodeId)
end

function M.search_tree_nodes(session, params)
    local service, err = requireTreeService(session)
    if not service then
        return nil, err
    end
    return service:search_tree_nodes(params)
end

function M.create_tree_snapshot(session)
    local service, err = requireTreeService(session)
    if not service then
        return nil, err
    end
    return service:create_tree_snapshot()
end

function M.restore_tree_snapshot(session, snapshot)
    local service, err = requireTreeService(session)
    if not service then
        return nil, err
    end
    return service:restore_tree_snapshot(snapshot)
end

function M.simulate_node_delta(session, params, fields)
    local service, err = requireTreeService(session)
    if not service then
        return nil, err
    end
    return service:simulate_node_delta(params, fields)
end

return M
