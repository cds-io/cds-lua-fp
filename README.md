# cds-lua-fp

Reusable list transformations and error propagation for Lua 5.1 and later,
including LuaJIT and Neovim. The library depends only on the Lua standard library.

Use `cds.fp` to express what a loop does: select records, extract fields,
find a match, or remove duplicates. Use `cds.result` when successive operations
can fail and you want to handle the first error once.

```lua
local result = require("cds.result")

local function number(text)
  local n = tonumber(text)
  if n == nil then return nil, "expected a number" end
  return n
end

local function positive(n)
  if n <= 0 then return nil, "must be positive" end
  return n
end

local value, err = number("3")
value, err = result.bind(value, err, positive)
assert(value == 3 and err == nil)
-- With "oops", positive is skipped and err stays "expected a number".
```

`cds.result` uses `value` for success and `nil, err` for failure; `false` and `0`
are successful values. Keep both returns in locals before calling `bind`:
Lua discards additional return values from a call followed by more arguments.
The list helpers use ordinary list and scalar results, not this error convention.
For example, `fp.map` creates a new list and raises if a callback returns nil,
while `fp.filter_map` omits nil results intentionally.

For plugins sharing the library, `cds.needs` checks required API names at startup
so users get an actionable update message. `cds.module` supplies diagnostics
when an absent API is called. Every public helper has language-server annotations
and examples in the generated reference.

## Installing

As a rock:

```
luarocks install cds-lua-fp
```

As a lazy.nvim plugin, with no luarocks on the machine:

```lua
{ "cds-io/cds-lua-fp", lazy = true }
```

[cds-lua](https://github.com/cds-io/cds-lua), a Neovim library built on it,
declares it as a dependency, so a plugin that takes cds-lua has it. Inside
Neovim, `:help cds-lua-fp` is the manual; the reference site,
[cds-io.github.io/cds-lua-fp](https://cds-io.github.io/cds-lua-fp/), has one
page per module from the same annotations.

## Developing

```
make check     # the specs under busted; stylua; luacheck; the type check; the help file
make doc       # doc/cds-lua-fp.txt, with mini.doc on the runtimepath
```

CI runs the specs on Lua 5.1, 5.4 and LuaJIT.

## Licence

MIT; see LICENSE.
