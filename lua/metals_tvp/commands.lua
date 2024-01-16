--This file should contain all commands meant to be used by mappings.
local cc = require("neo-tree.sources.common.commands")
local manager = require("neo-tree.sources.manager")
local neotree_utils = require("neo-tree.utils")
local utils = require("metals_tvp.utils")
local renderer = require("neo-tree.ui.renderer")
local log = utils.log
local async = require("plenary.async")
local lsp = require("metals_tvp.lsp")

local SOURCE_NAME = utils.SOURCE_NAME

local M = {}

M.refresh = neotree_utils.wrap(manager.refresh, SOURCE_NAME)
M.redraw = neotree_utils.wrap(manager.redraw, SOURCE_NAME)

M.show_debug_info = function(state)
    print(vim.inspect(state.tree))
end

local function fetch_recursively_expanded_nodes(result, state)
    local new_nodes = {}
    for _, tvp_node in pairs(result.nodes) do
        table.insert(new_nodes, utils.convert_node(tvp_node))
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
                    cnode.children = fetch_recursively_expanded_nodes(cresult, state)
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

M.execute_node_command = function(state, node)
    node = node or state.tree:get_node()
    if node.extra.command ~= nil then
        -- Jump to the last window so this doesn't open up in the actual tvp panel
        vim.cmd([[wincmd p]])
        lsp.execute_command(state.metals_buffer, node)
    end
end

local function toggle_node(state, node)
    local metals_buffer = state.metals_buffer
    node = node or state.tree:get_node()
    if node.extra.is_expandable then
        if node:is_expanded() then
            node:collapse()
            lsp.tree_view_node_collapse_did_change(metals_buffer, node:get_id(), true)
            renderer.redraw(state)
        else
            node:expand()
            if node.children then
                renderer.redraw(state)
            else
                lsp.tree_view_node_collapse_did_change(metals_buffer, node:get_id(), false)
                utils.async_void_run(function()
                    local err, result = lsp.tree_view_children(metals_buffer, node:get_id())
                    if err then
                        log.error(err)
                        log.error("Something went wrong while requesting tvp children. More info in logs.")
                    else
                        node.children = fetch_recursively_expanded_nodes(result, state)
                        renderer.show_nodes(node.children, state, node:get_id())
                    end
                end)
            end
        end
    else
        M.execute_node_command(state, node)
    end
end

M.toggle_node = function(state, node)
    toggle_node(state, node)
end

cc._add_common_commands(M)
return M
