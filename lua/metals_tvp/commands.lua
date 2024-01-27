--This file should contain all commands meant to be used by mappings.
local cc = require("neo-tree.sources.common.commands")
local manager = require("neo-tree.sources.manager")
local neotree_utils = require("neo-tree.utils")
local utils = require("metals_tvp.utils")
local renderer = require("neo-tree.ui.renderer")
local log = require("metals_tvp.logger")
local lsp = require("metals_tvp.lsp")

local SOURCE_NAME = utils.SOURCE_NAME

local M = {}

M.refresh = neotree_utils.wrap(manager.refresh, SOURCE_NAME)
M.redraw = neotree_utils.wrap(manager.redraw, SOURCE_NAME)

M.show_debug_info = function(state, node)
    -- print(vim.inspect(state.tree))
    print(vim.inspect(utils.internal_state))
end

M.show_debug_node_info = function(state, node)
    node = node or state.tree:get_node()
    if node then
        print(vim.inspect(node))
        print(vim.inspect(utils.internal_state.by_id[node:get_id()]))
    end
end

M.reveal_in_tree = function(state, node)
    return utils.async_void_run(function()
        local err, result = lsp.tree_reveal(state.metals_buffer, state.lsp_winid)
        if err then
            log.error(err)
            log.error("Something went wrong while requesting tree_reveal. More info in logs.")
            return
        end
        if not result then
            vim.notify("tree_reveal empty result")
            return
        end
        local _, last_uri = next(result.uriChain)
        utils.reverse(result.uriChain)

        local head = table.remove(result.uriChain, 1)
        local tvp_node = utils.internal_state.by_id[head]
        if tvp_node then
            local nui_node = state.tree:get_node(tvp_node.nodeUri)
            nui_node:expand()
            local children = utils.expand_node(state, tvp_node, result.uriChain)
            utils.append_state(children)
            local tree = utils.tree_to_nui(tvp_node)
            renderer.position.set(state, last_uri)
            renderer.show_nodes(tree.children, state, tvp_node.nodeUri)
        end
    end)
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
    local node = node or state.tree:get_node()
    local tvp_node = utils.internal_state.by_id[node:get_id()]

    if tvp_node.collapseState ~= nil then
        if tvp_node.collapseState == "expanded" then
            node:collapse()
            tvp_node.collapseState = "collapsed"
            lsp.tree_view_node_collapse_did_change(metals_buffer, tvp_node.nodeUri, true)
            renderer.redraw(state)
        else
            local update_ui = function()
                node:expand()
                tvp_node.collapseState = "expanded"
                lsp.tree_view_node_collapse_did_change(metals_buffer, tvp_node.nodeUri, false)
            end
            if node.children and #node.children > 0 then
                update_ui()
                renderer.redraw(state)
            else
                utils.async_void_run(function()
                    local children = utils.expand_node(state, tvp_node)
                    utils.append_state(children)
                    local tree = utils.tree_to_nui(tvp_node)
                    update_ui()
                    renderer.show_nodes(tree.children, state, tvp_node.nodeUri)
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
