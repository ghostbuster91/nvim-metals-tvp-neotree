# Metals TreeViewProtocol Neotree Integration

[tree-view protocol](https://scalameta.org/metals/docs/integrations/tree-view-protocol/)

[neo-tree](https://github.com/nvim-neo-tree/neo-tree.nvim)

## Motivation

Most of the time filesystem tree is enough for me. But there are cases where I want to explore 3rd party library by walking through its packages.
This is not possible using filesystem tree because of how metals handles such files internally.

But nvim-metals already supports treeViewProtocol!

That is correct, however I really care about consistent feel & behavior in my neovim hence I want all tree-like sources to be managed by neotree.

## Current state

treeViewProtocol is still experimental, so everything might break without prior notice.

Supported features:

- navigation around the tree and fetching of not-yet loaded nodes
- reveal in tree
- follow_cursor

Other neotree benefits:

- extensive ability to customize rendering

Known issues:

- Modules have to be compiled first otherwise you will get no results.
  Toggling a non-compiled module triggers the compilation, but results are not reported.
  Once the module was compiled, toggling it once again should work.
  This does not work on metals 1.2.0. See [#6023](https://github.com/scalameta/metals/issues/6029) for details.

[Demo.webm](https://github.com/ghostbuster91/nvim-metals-tvp-neotree/releases/download/v0.1.0/Kooha-2024-01-27-20-37-52.webm)

## Getting started

neotree configuration:

```lua
        metals_tvp = {
            follow_cursor = true,
            renderers = {
                root = {
                    { "indent" },
                    { "icon",  default = "C" },
                    { "name",  zindex = 10 },
                },
                symbol = {
                    { "indent",    with_expanders = true },
                    { "kind_icon", default = "?" },
                    {
                        "container",
                        content = {
                            { "name",      zindex = 10 },
                            { "kind_name", zindex = 20, align = "right" },
                        }
                    }
                },
            },
            window = {
                mappings = {
                    ["<cr>"] = "toggle_node",
                    ["<s-cr>"] = "execute_node_command",
                },
            }
        },
```

metals configuration:

```lua
metals_config.handlers = {
        ["metals/treeViewDidChange"] = function(_, result)
            require("metals_tvp.api").tree_view_did_change(result)
        end
    }
```

## Developer notes

What to test:

- open source before it is loaded
- open source once loaded -> libraries -> expand/collapse nodes
- jumping between metals-tvp and another buffer (make sure that we don't request any new data)
- follow_cursor both library and project
- make sure that non-compiled modules can be loaded eventually
- open a file from library and call reveal without having the tvp opened before
