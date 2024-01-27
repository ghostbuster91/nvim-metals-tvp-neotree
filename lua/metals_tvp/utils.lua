local kinds = require("neo-tree.sources.document_symbols.lib.kinds")
local async = require("plenary.async")
local lsp = require("metals_tvp.lsp")
local log = require("metals_tvp.logger")
local api = vim.api
local renderer = require("neo-tree.ui.renderer")

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
        node.extra.kind = kinds.get_kind(6) --TODO get proper kind
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

M.fetch_recursively_expanded_nodes = function(result, state)
    local new_nodes = result.nodes

    local tasks = {}
    for _, cnode in pairs(new_nodes) do
        if cnode.collapseState == collapse_state.expanded then
            local prepared = function()
                local err, cresult = lsp.tree_view_children(state.metals_buffer, cnode.nodeUri)

                if err then
                    log.error(err)
                    log.error("Something went wrong while requesting tvp children. More info in logs.")
                    return {}
                else
                    return M.fetch_recursively_expanded_nodes(cresult, state)
                end
            end
            table.insert(tasks, prepared)
        end
    end

    if #tasks > 0 then
        local rec_nodes_results = async.util.join(tasks)
        for _, rec_nodes in ipairs(rec_nodes_results) do
            for _, nodes in ipairs(rec_nodes) do
                for _, node in ipairs(nodes) do
                    table.insert(new_nodes, node)
                end
            end
        end
    end
    return new_nodes
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
    for _, node in ipairs(tvp_nodes) do
        local prev = M.internal_state.by_parent_id[node.parent_id or M.root_node_id] or {}
        table.insert(prev, node)
        M.internal_state.by_parent_id[node.parent_id or M.root_node_id] = prev
        if node.nodeUri ~= nil then
            M.internal_state.by_id[node.nodeUri] = node
        end
    end
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

return M
