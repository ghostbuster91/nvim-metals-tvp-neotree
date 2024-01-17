local events = require("neo-tree.events")

local M = {}

M.TREE_VIEW_DID_CHANGE_EVENT = "TREE_VIEW_DID_CHANGE_EVENT"

M.tree_view_did_change = function(nodes)
    events.fire_event(M.TREE_VIEW_DID_CHANGE_EVENT, nodes)
end

return M
