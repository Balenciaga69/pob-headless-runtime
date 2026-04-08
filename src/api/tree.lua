-- Internal convenience facade for tree-related calls.
local M = {}

-- Internal convenience facade. The formal public API is `api.init`.

-- Retrieves the tree service from the session, or returns nil if not available.
local function getTreeService(session)
    -- Resolve the tree service from the session.
    local services = session and session:getServices() or nil
    return services and services.tree or nil
end

-- Requires the tree service to be available, returning an error if not.
local function requireTreeService(session)
    -- Fail fast when the tree service is missing.
    local service = getTreeService(session)
    if not service then
        return nil, "tree service not available"
    end
    return service
end

-- Retrieves the entire tree structure for the session.
function M.get_tree(session)
    -- Return the current passive tree structure.
    local service, err = requireTreeService(session)
    if not service then
        return nil, err
    end
    return service:get_tree()
end

-- Retrieves a specific node from the tree by its ID.
function M.get_tree_node(session, nodeId)
    -- Return a single tree node by its id.
    local service, err = requireTreeService(session)
    if not service then
        return nil, err
    end
    return service:get_tree_node(nodeId)
end

-- Searches for tree nodes based on the provided parameters.
function M.search_tree_nodes(session, params)
    -- Search tree nodes using the provided filter parameters.
    local service, err = requireTreeService(session)
    if not service then
        return nil, err
    end
    return service:search_tree_nodes(params)
end

-- Creates a snapshot of the current tree state.
function M.create_tree_snapshot(session)
    -- Snapshot the current tree state.
    local service, err = requireTreeService(session)
    if not service then
        return nil, err
    end
    return service:create_tree_snapshot()
end

-- Restores the tree state from a given snapshot.
function M.restore_tree_snapshot(session, snapshot)
    -- Restore a previously captured tree snapshot.
    local service, err = requireTreeService(session)
    if not service then
        return nil, err
    end
    return service:restore_tree_snapshot(snapshot)
end

-- Simulates the delta of tree nodes based on provided parameters and fields.
function M.simulate_node_delta(session, params, fields)
    -- Simulate the stat delta caused by a node change.
    local service, err = requireTreeService(session)
    if not service then
        return nil, err
    end
    return service:simulate_node_delta(params, fields)
end

return M
