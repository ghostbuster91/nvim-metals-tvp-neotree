local kinds = require("metals_tvp.kinds")
local async = require("plenary.async")
local lsp = require("metals_tvp.lsp")
local log = require("metals_tvp.logger")
local api = vim.api
local renderer = require("neo-tree.ui.renderer")
local manager = require("neo-tree.sources.manager")

local M = {}

-- taken from https://github.com/scalameta/nvim-metals/blob/c905fff8d510447545163a5dff9d564d09e97bd8/lua/metals/util.lua#L102
---@return integer|nil
M.find_metals_buffer = function()
    local metals_buf = nil
    local bufs = api.nvim_list_bufs()

    for _, buf in pairs(bufs) do
        if api.nvim_buf_is_loaded(buf) then
            local buf_clients = vim.lsp.get_active_clients({ buffer = buf, name = "metals" })
            if #buf_clients > 0 then
                metals_buf = buf
                break
            end
        end
    end
    return metals_buf
end

-- NOTE: this is a bit of a hack since once we create the tvp panel, we can
-- no longer use 0 as the buffer to send the requests so we store a valid
-- buffer that Metals is attatched to. It doesn't really matter _what's_ in
-- that buffer, as long as Metals is attatched.
---@return integer|nil
M.valid_metals_buffer = function(state)
    if state.metals_buffer ~= nil and api.nvim_buf_is_loaded(state.metals_buffer) then
        return state.metals_buffer
    else
        local valid_buf = M.find_metals_buffer()
        state.metals_buffer = valid_buf
        return valid_buf
    end
end

local collapse_state = {
    expanded = "expanded",
    collapsed = "collapsed",
}

M.convert_node = function(raw_node)
    local node = {}
    node.name = raw_node.label
    node.id = raw_node.nodeUri
    node.children = {}
    node.extra = {}
    node.extra.kind = {
        icon = "",
    }
    if raw_node.collapseState ~= nil then
        node._is_expanded = raw_node.collapseState == collapse_state.expanded
        node.extra.is_expandable = true
    end
    if raw_node.icon ~= nil then
        node.extra.kind = kinds.get_kind(raw_node.icon)
    end
    if raw_node.command ~= nil then
        node.extra.command = raw_node.command
    end
    if raw_node.type then
        node.type = raw_node.type
    elseif raw_node.icon then
        node.type = "symbol"
        node.extra.kind.name = raw_node.icon
    else
        node.type = "directory"
    end
    return node
end

M.SOURCE_NAME = "metals_tvp"

M.async_void_run = function(wrapped)
    local empty_callback = function() end
    async.run(wrapped, empty_callback)
end

M.expand_node = function(state, node, uri_chain)
    if node.collapseState ~= nil then
        node.collapseState = collapse_state.expanded
        local state_children = M.internal_state.by_parent_id[node.nodeUri]
        if state_children and #state_children > 0 then
            return M.expand_children_rec(state_children, state, uri_chain)
        else
            local err, lsp_results = lsp.tree_view_children(state.metals_buffer, node.nodeUri)
            if err then
                log.error(err)
                log.error("Something went wrong while requesting tvp children. More info in logs.")
                return {}
            else
                return M.expand_children_rec(lsp_results.nodes, state, uri_chain)
            end
        end
    else
        return {}
    end
end

M.expand_children_rec = function(result, state, uri_chain)
    local follow_uri = nil
    if uri_chain and #uri_chain > 0 then
        follow_uri = table.remove(uri_chain, 1)
    end

    local tasks = {}
    for _, cnode in pairs(result) do
        local should_follow = follow_uri == cnode.nodeUri

        if cnode.collapseState == collapse_state.expanded or should_follow then
            table.insert(tasks, function()
                if should_follow then
                    return M.expand_node(state, cnode, uri_chain)
                else
                    return M.expand_node(state, cnode, nil)
                end
            end)
        end
    end

    if #tasks > 0 then
        local rec_nodes_results = async.util.join(tasks)
        for _, rec_nodes in ipairs(rec_nodes_results) do
            for _, nodes in ipairs(rec_nodes) do
                for _, node in ipairs(nodes) do
                    table.insert(result, node)
                end
            end
        end
    end
    return result -- todo should this be a new table?
end

M.debug = function(state)
    local window_exists = renderer.window_exists(state)
    local tree_visible = renderer.tree_is_visible(state)
    local tree_not_null = state.tree ~= nil

    vim.notify([[tree state:
    window_exists: ]] .. vim.inspect(window_exists) .. [[
    tree_visible: ]] .. vim.inspect(tree_visible) .. [[
    tree_not_null: ]] .. vim.inspect(tree_not_null))
end

M.root_node_id = "0"

M.internal_state = {
    by_parent_id = {},
    by_id = {},
}
-- todo we always append, when should we remove?
M.append_state = function(tvp_nodes)
    local grouped_by_parent = {}
    for _, node in ipairs(tvp_nodes) do
        local group = grouped_by_parent[node.parent_id or M.root_node_id] or {}
        table.insert(group, node)
        grouped_by_parent[node.parent_id or M.root_node_id] = group
    end
    for parent_id, children in pairs(grouped_by_parent) do
        M.internal_state.by_parent_id[parent_id] = children
        for _, node in ipairs(children) do
            if node.nodeUri ~= nil then
                M.internal_state.by_id[node.nodeUri] = node
            end
        end
    end
end

M.init_state = function()
    M.internal_state.by_id[M.root_node_id] = M.create_root()
end

M.create_root = function()
    local root = {
        nodeUri = M.root_node_id,
        label = "metals tvp",
        type = "root",
        collapseState = "expanded",
    }

    return root
end

M.tree_to_nui = function(tvp_node)
    local nui_node = M.convert_node(tvp_node)
    local children = M.internal_state.by_parent_id[tvp_node.nodeUri] or {}

    local child_nui_node = {}
    for _, node in ipairs(children) do
        table.insert(child_nui_node, M.tree_to_nui(node))
    end
    nui_node.children = child_nui_node
    return nui_node
end

M.reverse = function(t)
    for i = 1, math.floor(#t / 2) do
        local j = #t - i + 1
        t[i], t[j] = t[j], t[i]
    end
end

M.get_state = function()
    return manager.get_state(M.SOURCE_NAME)
end

return M
