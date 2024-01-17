local kinds = require("neo-tree.sources.document_symbols.lib.kinds")
local async = require("plenary.async")
local lsp = require("metals_tvp.lsp")
local log = require("metals_tvp.logger")
local api = vim.api

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
    if raw_node.icon then
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
    local new_nodes = {}
    for _, tvp_node in pairs(result.nodes) do
        table.insert(new_nodes, M.convert_node(tvp_node))
    end

    local tasks = {}
    for _, cnode in pairs(new_nodes) do
        if cnode._is_expanded then
            local prepared = function()
                local err, cresult = lsp.tree_view_children(state.metals_buffer, cnode.id)

                if err then
                    log.error(err)
                    log.error("Something went wrong while requesting tvp children. More info in logs.")
                else
                    cnode.children = M.fetch_recursively_expanded_nodes(cresult, state)
                end
            end
            table.insert(tasks, prepared)
        end
    end

    if #tasks > 0 then
        async.util.join(tasks)
    end
    return new_nodes
end

return M
