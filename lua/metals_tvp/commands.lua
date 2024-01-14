--This file should contain all commands meant to be used by mappings.
local cc = require("neo-tree.sources.common.commands")
local manager = require("neo-tree.sources.manager")
local neotree_utils = require("neo-tree.utils")
local utils = require("metals_tvp.utils")
local renderer = require("neo-tree.ui.renderer")
local log = utils.log
local SOURCE_NAME = utils.SOURCE_NAME

local M = {}

M.refresh = neotree_utils.wrap(manager.refresh, SOURCE_NAME)
M.redraw = neotree_utils.wrap(manager.redraw, SOURCE_NAME)
-- M.open = M.toggle_node

M.show_debug_info = function(state)
    print(vim.inspect(state))
end


-- Notify the server that the collapse stated for a node has changed
-- @param view_id (string) the view id that contains the node
-- @param node_uri (string) uri of the node
-- @param collapsed (boolean)
local function tree_view_node_collapse_did_change(bufnr, view_id, node_uri, collapsed)
    vim.lsp.buf_notify(
        bufnr,
        "metals/treeViewNodeCollapseDidChange",
        { viewId = view_id, nodeUri = node_uri, collapsed = collapsed }
    )
end

local function handleTreeViewChildrenResults(result, state, node_id_to_update)
    local new_nodes = {}
    for _, node in pairs(result.nodes) do
        table.insert(new_nodes, utils.convert_node(node))
    end

    local tree = state.tree
    local node = tree:get_node(node_id_to_update)
    node.children = new_nodes

    renderer.show_nodes(node.children, state, node_id_to_update, function()
        for _, cnode in pairs(node.children) do
            if cnode._is_expanded then
                vim.lsp.buf_request(utils.valid_metals_buffer(), "metals/treeViewChildren",
                    { viewId = utils.metals_packages, nodeUri = cnode.id },
                    function(err, result)
                        if err then
                            log.error(err)
                            log.error("Something went wrong while requesting tvp children. More info in logs.")
                        else
                            handleTreeViewChildrenResults(result, state, cnode.id)
                        end
                    end)
            end
        end
    end)
end

local function execute_node_command(state, node)
    node = node or state.tree:get_node()
    if node.extra.command ~= nil then
        -- Jump to the last window so this doesn't open up in the actual tvp panel
        vim.cmd([[wincmd p]])
        vim.lsp.buf_request(utils.valid_metals_buffer(), "workspace/executeCommand", {
            command = node.extra.command.command,
            arguments = node.extra.command.arguments,
        }, function(err, _, _)
            if err then
                log.error("Unable to execute node command.")
            end
        end)
    end
end

M.execute_node_command = function(state, node)
    execute_node_command(state, node)
end

local function toggle_node(state, node)
    node = node or state.tree:get_node()
    vim.notify("toggle_node " .. vim.inspect(node.extra))
    if node.extra.is_expandable then
        if node:is_expanded() then
            node:collapse()
            tree_view_node_collapse_did_change(utils.valid_metals_buffer(), utils.metals_packages, node:get_id(), true)
        else
            node:expand()
            tree_view_node_collapse_did_change(utils.valid_metals_buffer(), utils.metals_packages, node:get_id(), false)
            local tree_view_children_params = { viewId = utils.metals_packages }
            if node ~= nil then
                tree_view_children_params["nodeUri"] = node:get_id()
            end
            vim.lsp.buf_request(utils.valid_metals_buffer(), "metals/treeViewChildren", tree_view_children_params,
                function(err, result)
                    if err then
                        log.error(err)
                        log.error("Something went wrong while requesting tvp children. More info in logs.")
                    else
                        handleTreeViewChildrenResults(result, state, node:get_id())
                    end
                end)
        end
        renderer.redraw(state)
    else
        execute_node_command(state, node)
    end
end



M.toggle_node = function(state, node)
    toggle_node(state, node)
end

cc._add_common_commands(M)
return M
