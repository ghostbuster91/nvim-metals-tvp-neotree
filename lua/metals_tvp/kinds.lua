-- copied from neotree source, how to deduplicate?

local kinds = {
    unknown = { icon = "?", hl = "" },
    root = { icon = "", hl = "NeoTreeRootName" },
    file = { icon = "󰈙", hl = "Tag" },
    module = { icon = "", hl = "Exception" },
    namespace = { icon = "󰌗", hl = "Include" },
    package = { icon = "󰏖", hl = "Label" },
    class = { icon = "󰌗", hl = "Include" },
    method = { icon = "", hl = "Function" },
    property = { icon = "󰆧", hl = "@property" },
    field = { icon = "", hl = "@field" },
    constructor = { icon = "", hl = "@constructor" },
    enum = { icon = "󰒻", hl = "@number" },
    interface = { icon = "", hl = "Type" },
    ["function"] = { icon = "󰊕", hl = "Function" },
    variable = { icon = "", hl = "@variable" },
    constant = { icon = "", hl = "Constant" },
    string = { icon = "󰀬", hl = "String" },
    number = { icon = "󰎠", hl = "Number" },
    boolean = { icon = "", hl = "Boolean" },
    array = { icon = "󰅪", hl = "Type" },
    object = { icon = "󰅩", hl = "Type" },
    key = { icon = "󰌋", hl = "" },
    null = { icon = "", hl = "Constant" },
    enumMember = { icon = "", hl = "Number" },
    struct = { icon = "󰌗", hl = "Type" },
    event = { icon = "", hl = "Constant" },
    operator = { icon = "󰆕", hl = "Operator" },
    typeParameter = { icon = "󰊄", hl = "Type" },
}

M = {}

M.get_kind = function(tpe)
    return kinds[tpe] or kinds["unknown"]
end

return M
