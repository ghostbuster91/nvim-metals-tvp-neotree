local async = require("plenary.async")
local utils = require("metals_tvp.utils")

local M = {}

local metals_packages = "metalsPackages"
local async_buf_request = async.wrap(vim.lsp.buf_request, 4)

-- [async] Get children for a given parent
-- @param view_id (string) the view id that contains the node
-- @param node_uri (string) parent id
M.tree_view_children = function(bufnr, node_uri)
    return async_buf_request(bufnr, "metals/treeViewChildren", M.make_tree_view_children_params(node_uri))
end

M.make_tree_view_children_params = function(node_uri)
    return { viewId = metals_packages, nodeUri = node_uri }
end

-- Notify the server that the collapse stated for a node has changed
-- @param node_uri (string) uri of the node
-- @param collapsed (boolean)
M.tree_view_node_collapse_did_change = function(bufnr, node_uri, collapsed)
    -- view_id (string) the view id that contains the node
    local view_id = metals_packages
    vim.lsp.buf_notify(
        bufnr,
        "metals/treeViewNodeCollapseDidChange",
        { viewId = view_id, nodeUri = node_uri, collapsed = collapsed }
    )
end

M.execute_command = function(bufnr, node)
    vim.lsp.buf_request(bufnr, "workspace/executeCommand", {
        command = node.extra.command.command,
        arguments = node.extra.command.arguments,
    }, function(err, _, _)
        if err then
            utils.log.error("Unable to execute node command.")
        end
    end)
end

return M
