--This file should have all functions that are in the public api and either set
--or read the state of this source.

local vim = vim
local renderer = require("neo-tree.ui.renderer")
local utils = require("metals_tvp.utils")
local neotree_utils = require("neo-tree.utils")
local log = utils.log
local SOURCE_NAME = utils.SOURCE_NAME

local M = {
    -- This is the name our source will be referred to as
    -- within Neo-tree
    name = SOURCE_NAME,
    -- This is how our source will be displayed in the Source Selector
    display_name = "Metals TVP"
}

local function handleTreeViewChildrenResults(result, state)
    local new_nodes = {}
    for _, node in pairs(result.nodes) do
        table.insert(new_nodes, utils.convert_node(node))
    end
    local root = {
        id = "0",
        name = "metals tvp",
        type = "root",
        children = new_nodes,
        extra = {
            kind = {
                icon = ""
            }
        }
    }

    renderer.show_nodes({ root }, state)
end

---Navigate to the given path.
---@param path string Path to navigate to. If empty, will navigate to the cwd.
M.navigate = function(state, target_node)
    state.lsp_winid, _ = neotree_utils.get_appropriate_window(state)
    state.lsp_bufnr = vim.api.nvim_win_get_buf(state.lsp_winid)
    state.path = vim.api.nvim_buf_get_name(state.lsp_bufnr)

    local tree = state.tree
    if not tree or not renderer.window_exists(state) then
        vim.notify("get nodes !!")
        local opts = {}
        local tree_view_children_params = { viewId = utils.metals_packages }
        if opts.parent_uri ~= nil then
            tree_view_children_params["nodeUri"] = opts.parent_uri
        end
        vim.lsp.buf_request(utils.valid_metals_buffer(), "metals/treeViewChildren", tree_view_children_params,
            function(err, result)
                if err then
                    log.error(err)
                    log.error("Something went wrong while requesting tvp children. More info in logs.")
                else
                    handleTreeViewChildrenResults(result, state)
                end
            end)
    else
        target_node = target_node or tree and tree:get_node()
        if target_node then
            vim.notify("redraw !!")
            renderer.redraw(state)
        else
            vim.notify("show nodes !!")
            renderer.show_nodes(tree:get_node("0"), state)
        end
    end
end



---Configures the plugin, should be called before the plugin is used.
---@param config table Configuration table containing any keys that the user
--wants to change from the defaults. May be empty to accept default values.
M.setup = function(config, global_config)
    --TODO do we need anything in here?
end

return M
