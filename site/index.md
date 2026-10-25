---
title: cds-lua-fp
nav_order: 1
permalink: /
---

# cds-lua-fp

A small functional vocabulary for Lua, 5.1 and up: `cds.fp` for lists,
`cds.result` for Lua's own error convention, `cds.module`, a fallback a module
returns through so a name it does not have fails at the call, in words, and
`cds.needs`, a check a program runs at startup for the functions it declares.

```lua
local fp = require("cds.fp")
local result = require("cds.result")

local titles = fp.map(entries, function(entry)
  return entry.title
end)
local parsed, err = result.bind(read(path), nil, parse)
```

Every function answers `value` or `nil, err`, and only `nil` fails, so `false`
and `0` are valid answers. `fp.map` refuses a `nil` answer, since a hole would
stop `ipairs` reading the list; `fp.set` and `fp.unique` refuse a `nil` key,
naming the item. The function argument comes last, so one written out over
several lines reads as a block under the call. Every function carries
language-server annotations, generic over the item type, so `fp.map` over a
`T[]` answers a `U[]` in the editor.

## Installing

As a rock:

```
luarocks install cds-lua-fp
```

As a lazy.nvim plugin, with no luarocks on the machine:

```lua
{ "cds-io/cds-lua-fp", lazy = true }
```

Inside Neovim, `:help cds-lua-fp` is the manual.

## Reading on

- [Modules](modules/): one page per module, from the annotations in the source.
- The source: [github.com/cds-io/cds-lua-fp](https://github.com/cds-io/cds-lua-fp);
  `make check` runs the specs under busted, stylua, luacheck, the language
  server's type check and the help file's freshness.
