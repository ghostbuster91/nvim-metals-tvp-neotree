--This file should have all functions that are in the public api and either set
--or read the state of this source.

local vim = vim
local renderer = require("neo-tree.ui.renderer")
local utils = require("metals_tvp.utils")
local lsp = require("metals_tvp.lsp")
local neotree_utils = require("neo-tree.utils")
local log = require("metals_tvp.logger")
local kinds = require("neo-tree.sources.document_symbols.lib.kinds")
local events = require("neo-tree.events")
local api = require("metals_tvp.api")
local manager = require("neo-tree.sources.manager")
local async = require("plenary.async")

local SOURCE_NAME = utils.SOURCE_NAME

local M = {
    -- This is the name our source will be referred to as
    -- within Neo-tree
    name = SOURCE_NAME,
    -- This is how our source will be displayed in the Source Selector
    display_name = "Metals TVP",
}

---Navigate to the given path.
---@param path string Path to navigate to. If empty, will navigate to the cwd.
M.navigate = function(state, target_node)
    state.lsp_winid, _ = neotree_utils.get_appropriate_window(state)
    state.lsp_bufnr = vim.api.nvim_win_get_buf(state.lsp_winid)
    state.path = vim.api.nvim_buf_get_name(state.lsp_bufnr)
    state.metals_buffer = utils.valid_metals_buffer(state)

    utils.debug(state)

    -- if no client found, terminate
    if not state.metals_buffer then
        local bufname = state.path
        renderer.show_nodes({
            {
                id = "0",
                name = "No metals client found or in-progress",
                path = bufname,
                type = "root",
                children = {},
                extra = { kind = kinds.get_kind(0), search_path = "/" },
            },
        }, state)
    else
        if not state.tree or not renderer.window_exists(state) then
            renderer.show_nodes({ utils.tree_to_nui(utils.create_root()) }, state)
        else
            renderer.redraw(state)
        end
    end
end

---Configures the plugin, should be called before the plugin is used.
---@param config table Configuration table containing any keys that the user
--wants to change from the defaults. May be empty to accept default values.
M.setup = function(config, global_config)
    events.define_event(api.TREE_VIEW_DID_CHANGE_EVENT, { debounce_frequency = 0 })
    utils.append_state(utils.create_root())

    manager.subscribe(SOURCE_NAME, {
        event = api.TREE_VIEW_DID_CHANGE_EVENT,
        handler = function(result)
            local state = manager.get_state(SOURCE_NAME)
            vim.notify("tree view did change handler")
            if not state then
                vim.notify("state was null")
                return
            end
            state.metals_buffer = utils.valid_metals_buffer(state)
            vim.notify("state load")

            local refresh_node = function(node)
                vim.notify("refresh node")
                local err, result = lsp.tree_view_children(state.metals_buffer, node.nodeUri)
                if err then
                    log.error(err)
                    log.error("Something went wrong while requesting tvp children. More info in logs.")
                else
                    local children = utils.fetch_recursively_expanded_nodes(result, state)
                    utils.append_state(children)
                    renderer.show_nodes(utils.tree_to_nui(node), state, node.nodeUri)
                end
            end
            local tasks = {}
            for _, node in pairs(result.nodes) do
                -- we are only interested in nodes that have uri
                if node.nodeUri then
                    table.insert(tasks, function()
                        -- from neovim-metals:
                        -- As far as I know, the res.nodes here will never be children of eachother, so we
                        -- should be safe doing this call for the children in the same loop as the update.
                        refresh_node(node)
                    end)
                end
            end
            utils.async_void_run(function()
                if #tasks > 0 then
                    vim.notify("async tasks > 0")
                    async.util.join(tasks)
                else
                    vim.notify("render root")
                    --TODO kind of hacky
                    local err, result = lsp.tree_view_children(state.metals_buffer, nil)
                    if err then
                        log.error(err)
                        log.error("Something went wrong while requesting tvp children. More info in logs.")
                    else
                        utils.append_state(result.nodes)
                        local tree = utils.tree_to_nui(utils.create_root())
                        renderer.show_nodes({ tree }, state)
                    end
                end
            end)
        end,
    })
end

return M
