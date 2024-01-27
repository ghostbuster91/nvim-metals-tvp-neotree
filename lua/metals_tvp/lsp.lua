local async = require("plenary.async")
local log = require("metals_tvp.logger")

local M = {}

local metals_packages = "metalsPackages"
M.metals_packages = metals_packages

-- [async] Get children for a given parent
-- @param view_id (string) the view id that contains the node
-- @param node_uri (string) parent id
M.tree_view_children = function(bufnr, node_uri)
    local async_buf_request = async.wrap(vim.lsp.buf_request, 4)
    local err, result = async_buf_request(bufnr, "metals/treeViewChildren", M.make_tree_view_children_params(node_uri))
    if result ~= nil then
        for _, node in ipairs(result.nodes) do
            node.parent_id = node_uri
        end
    end
    return err, result
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
            log.error("Unable to execute node command.")
        end
    end)
end

M.tree_reveal = function(bufnr)
    local async_buf_request = async.wrap(vim.lsp.buf_request, 4)
    local params = vim.lsp.util.make_position_params()
    local err, result = async_buf_request(bufnr, "metals/treeViewReveal", params)
    return err, result
end

-- vim.lsp.buf_request(valid_metals_buffer(), "metals/treeViewReveal", params, function(err, result, ctx)
--       if err then
--         log.error_and_show(string.format("Error when executing: %s. Check the metals logs for more info.", ctx.method))
--       elseif result then
--         if result.viewId == metals_packages then
--           if api.nvim_get_current_win() ~= state.tvp_tree.win_id then
--             vim.fn.win_gotoid(state.tvp_tree.win_id)
--           end
--
--           util.reverse(result.uriChain)
--           local head = table.remove(result.uriChain, 1)
--
--           state.tvp_tree:tree_view_children({
--             view_id = result.viewId,
--             parent_uri = head,
--             additionals = result.uriChain,
--             expand = true,
--             focus = true,
--           })
--         else
--           log.warn_and_show(
--             string.format("You recieved a node for a view nvim-metals doesn't support: %s", result.viewId)
--           )
--         end
--       else
--         log.warn_and_show(messages.scala_3_tree_view)
--       end
--     end)

return M
