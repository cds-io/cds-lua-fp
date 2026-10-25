---@tag cds.module
---@toc_entry Names a module does not have
---@text
--- Give callers a useful error when they call an API that is missing from an
--- installed library. `wrap` makes the error identify both the module and the
--- requested name, helping distinguish a typo from an outdated dependency.
--- Every module in cds-lua-fp except this one uses it.
---
--- Wrap a module when returning its public table: >lua
---
---   local module = require("cds.module")
---   local api = module.wrap("example", { greet = function() return "hello" end })
---   assert(api.greet() == "hello")
---   local ok, err = pcall(function() api.greet_missing() end)
---   assert(not ok and err:find('cds.example has no "greet_missing"', 1, true))
--- <
--- A missing lookup returns a fallback function; the error occurs when that
--- function is called. Consequently, `if api.some_name then` cannot test
--- whether an API exists. Use |cds.module.is_fallback()| or |cds.needs.check()|
--- for that purpose. `wrap` replaces the table's metatable, so use it on plain
--- module tables, not tables whose existing metamethods must be preserved.
---@class cds.module
local M = {}

-- every fallback handed out, weakly, so is_fallback knows them
local fallbacks = setmetatable({}, { __mode = "k" })

--- Attach missing-API diagnostics to a module table and return the same table.
--- Existing fields keep their values. `name` is the suffix after `cds.`, such
--- as `fp` or `html.blocks`, and is used in the error message.
---
--- >lua
---   local module = require("cds.module")
---   local api = { version = 1 }
---   assert(module.wrap("example", api) == api)
---   assert(api.version == 1)
--- <
---@generic T: table
---@param name string  -- "fp", "html.blocks"
---@param mod T
---@return T
function M.wrap(name, mod)
  return setmetatable(mod, {
    __index = function(_, key)
      local fallback = function()
        error(
          ("cds.%s has no %q: the cds-lua installed is older than this code needs, or the name is misspelt"):format(
            name,
            tostring(key)
          ),
          2
        )
      end
      fallbacks[fallback] = true
      return fallback
    end,
  })
end

--- Identify a function created by `wrap` for a missing field. Use this after a
--- normal lookup so capability checks work with wrapped modules. For a general
--- presence check, also reject nil, which an unwrapped module may return.
---
--- >lua
---   local module = require("cds.module")
---   local api = module.wrap("example", { run = function() end })
---   assert(not module.is_fallback(api.run))
---   assert(module.is_fallback(api.missing))
---   assert(not module.is_fallback(nil))
--- <
---@param value any
---@return boolean
function M.is_fallback(value)
  return fallbacks[value] == true
end

-- `return require("cds.module").wrap(name, M)` is the form every module ends
-- with. The call goes through the named function because the language server
-- carries `wrap`'s generic (the module's own type comes back out) and loses it
-- through a `__call` metamethod, where the result is unknown to every caller.
return M
