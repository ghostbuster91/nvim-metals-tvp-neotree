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
local commands = require("metals_tvp.commands")

local SOURCE_NAME = utils.SOURCE_NAME

local M = {
    -- This is the name our source will be referred to as
    -- within Neo-tree
    name = SOURCE_NAME,
    -- This is how our source will be displayed in the Source Selector
    display_name = "Metals TVP",
}

---Follow the cursor with debouncing
---@param args { afile: string }
local follow_debounced = function(args)
    if neotree_utils.is_real_file(args.afile) == false then
        return
    end

    neotree_utils.debounce("document_symbols_follow", function()
        local state = utils.get_state()
        if state.lsp_bufnr ~= vim.api.nvim_get_current_buf() then
            return
        end
        commands.reveal_in_tree(state, nil)
    end, 120, neotree_utils.debounce_strategy.CALL_LAST_ONLY)
end

---Navigate to the given path.
---@param path string Path to navigate to. If empty, will navigate to the cwd.
M.navigate = function(state, path, path_to_reveal)
    state.lsp_winid, _ = neotree_utils.get_appropriate_window(state)
    state.lsp_bufnr = vim.api.nvim_win_get_buf(state.lsp_winid)
    state.path = vim.api.nvim_buf_get_name(state.lsp_bufnr)
    state.metals_buffer = utils.valid_metals_buffer(state)

    utils.debug(state)
    if state.tree and path_to_reveal then
        return commands.reveal_in_tree(state, nil)
    end

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
            utils.async_void_run(function()
                if path_to_reveal then
                    local reveal_result = commands.reveal_in_tree_internal(state)
                    if reveal_result then
                        renderer.position.set(state, reveal_result.last_uri)
                    end
                end
                renderer.show_nodes({ utils.tree_to_nui(utils.create_root()) }, state, nil)
            end)
        else
            renderer.redraw(state)
        end
    end
end

local handle_treeview_did_change = function(nodes)
    local state = utils.get_state()
    if not state then
        return
    end
    state.metals_buffer = utils.valid_metals_buffer(state)
    log.info("state loaded")

    local refresh_node = function(node)
        local children = utils.expand_node(state, node, nil)
        utils.append_state(children)
    end
    local tasks = {}
    for _, node in pairs(nodes) do
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
            async.util.join(tasks)
        else
            --TODO kind of hacky
            local err, result = lsp.tree_view_children(state.metals_buffer, nil)
            if err then
                log.error(err)
                log.error("Something went wrong while requesting tvp children. More info in logs.")
            else
                utils.append_state(result.nodes)
            end
        end
    end)
end

---Configures the plugin, should be called before the plugin is used.
---@param config table Configuration table containing any keys that the user
--wants to change from the defaults. May be empty to accept default values.
M.setup = function(config, global_config)
    events.define_event(api.TREE_VIEW_DID_CHANGE_EVENT, { debounce_frequency = 0 })
    utils.init_state()

    manager.subscribe(SOURCE_NAME, {
        event = api.TREE_VIEW_DID_CHANGE_EVENT,
        handler = function(hargs)
            handle_treeview_did_change(hargs.nodes)
        end,
    })

    if config.follow_cursor then
        manager.subscribe(M.name, {
            event = events.VIM_CURSOR_MOVED,
            handler = follow_debounced,
        })
    end
end

return M
