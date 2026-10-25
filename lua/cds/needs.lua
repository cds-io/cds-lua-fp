---@tag cds.needs
---@toc_entry Taking the library
---@text
--- Check required library APIs before a plugin starts, so an outdated
--- installation produces one actionable message instead of failing later in
--- an unrelated command. Declare the names the plugin uses, then run `check`
--- at its entry point. This checks availability, not function signatures or
--- behavior, so it complements version constraints and tests.
---
--- For example, check the requirements of a plugin that transforms lists: >lua
---
---   local needs = require("cds.needs")
---   local capabilities = { fp = { "map", "filter" }, result = { "bind" } }
---   local problem = needs.check("example.nvim", capabilities)
---   assert(problem == nil) -- these APIs are available in this library
---
---   problem = needs.check("example.nvim", { fp = { "not_an_api" } })
---   assert(problem:find("fp.not_an_api", 1, true))
---   assert(problem:find("cds-io/cds-lua-fp", 1, true))
--- <
--- In a plugin entry point, report a non-nil problem and return before
--- registering commands or autocommands. Load `cds.needs` with `pcall(require,
--- "cds.needs")` there too: an installation too old to include this module
--- cannot check its own capabilities.
---
--- Keep the declaration in one module, such as `lua/example/needs.lua`, and
--- use the same table with |cds.needs.strict()| in the test harness. This catches
--- new library calls that were added without updating the startup check.
--- Declare table-valued APIs, such as `http.status`, by their top-level name.
---
--- Install cds-lua-fp directly for the pure Lua helpers. A Neovim plugin using
--- APIs from cds-lua should declare that library as a dependency; it brings
--- cds-lua-fp with it. Missing-API messages name the library to install or
--- update: cds-lua-fp for `fp`, `result`, `module`, and `needs`; cds-lua for the
--- remaining modules.

local fp = require("cds.fp")
local module = require("cds.module")

---@class cds.needs
local M = {}

-- The stack as debug.getinfo and error count it from inside a metamethod:
-- level 1 is the metamethod itself, level 2 the function whose `module.name`
-- invoked it, the one a report is about.
local INDEXER = 2

---@alias cds.needs.Capabilities table<string, string[]>  -- cds module to the functions used

--- Lists the modules named, in name order.
---@param capabilities cds.needs.Capabilities
---@return string[]
local function modules(capabilities)
  local names = fp.keys(capabilities)
  table.sort(names)
  return names
end

--- Whether the module has something under the name: a lookup that answers
--- nothing, or answers the library's own fallback for a missing name
--- (cds.module), is a name it lacks.
---@param mod table
---@param fn string
---@return boolean
local function has(mod, fn)
  local value = mod[fn]
  return value ~= nil and not module.is_fallback(value)
end

--- Return the missing APIs as qualified names for custom diagnostics. Modules
--- are checked in sorted order, and names within a module retain declaration
--- order. If a module cannot load, all its declared names are missing. Any
--- non-nil value counts as present unless it is a `cds.module` fallback.
---
--- >lua
---   local needs = require("cds.needs")
---   local missing = needs.missing({ fp = { "map", "not_an_api" } })
---   assert(#missing == 1 and missing[1] == "fp.not_an_api")
--- <
---@param capabilities cds.needs.Capabilities
---@return string[]
function M.missing(capabilities)
  return fp.flat_map(modules(capabilities), function(name)
    local ok, mod = pcall(require, "cds." .. name)
    local lacking = fp.filter(capabilities[name], function(fn)
      return not (ok and type(mod) == "table" and has(mod, fn))
    end)
    return fp.map(lacking, function(fn)
      return name .. "." .. fn
    end)
  end)
end

-- The modules this rock carries; every other cds module is cds-lua's.
local ROCK = { fp = true, result = true, module = true, needs = true }

--- Return nil when all declared APIs are available. Otherwise, return one
--- message naming the plugin, the missing APIs, and the libraries to install
--- or update. The caller owns how that message is displayed; this function
--- does not notify, throw, or disable the plugin itself.
---
--- >lua
---   local needs = require("cds.needs")
---   assert(needs.check("example.nvim", { fp = { "map" } }) == nil)
---   local problem = needs.check("example.nvim", { fp = { "not_an_api" } })
---   assert(problem == "example.nvim needs cds-lua-fp with fp.not_an_api: "
---     .. "install or update cds-io/cds-lua-fp")
--- <
---@param plugin string  -- truth-table.nvim
---@param capabilities cds.needs.Capabilities
---@return string|nil
function M.check(plugin, capabilities)
  local missing = M.missing(capabilities)
  if #missing == 0 then
    return nil
  end
  local homes = { "cds-lua-fp", "cds-lua" }
  local by_home = { ["cds-lua-fp"] = {}, ["cds-lua"] = {} }
  for _, name in ipairs(missing) do
    local home = ROCK[name:match("^[^.]+")] and homes[1] or homes[2]
    table.insert(by_home[home], name)
  end
  local needs, remedies = {}, {}
  for _, home in ipairs(homes) do
    if #by_home[home] > 0 then
      needs[#needs + 1] = ("%s with %s"):format(home, table.concat(by_home[home], ", "))
      remedies[#remedies + 1] = "cds-io/" .. home
    end
  end
  return ("%s needs %s: install or update %s"):format(
    plugin,
    table.concat(needs, " and "),
    table.concat(remedies, " and ")
  )
end

--- Whether a function is one of this library's own: its chunk is a file
--- under lua/cds/. The library's modules use each other beyond any one
--- plugin's declaration, so they pass.
---@param info table|nil  -- debug.getinfo(_, "S") of the function; nil for none
---@return boolean
local function in_library(info)
  return info ~= nil and info.source:find("lua/cds/", 1, true) ~= nil
end

--- Catch undeclared library usage during tests. Before loading plugin modules,
--- call this with the same capabilities used by the startup check. It replaces
--- declared modules in `package.loaded` with proxies that reject reads of
--- undeclared names. Modules absent from the declaration are not intercepted.
---
--- Writes pass through to the original module, allowing tests to replace hooks.
--- Calls originating inside `lua/cds/` are exempt, since the library's own
--- implementation may need additional APIs. Modules that cannot load are
--- skipped. Run this in a test process, not in normal plugin startup: the
--- proxies persist for the lifetime of that process.
---
--- >lua
---   local needs = require("cds.needs")
---   local capabilities = { fp = { "map" } }
---   needs.strict("example.nvim", capabilities)
---   local fp = require("cds.fp") -- require after installing the proxies
---   assert(fp.map({ 2 }, function(n) return n * 2 end)[1] == 4)
---   local ok, err = pcall(function() return fp.filter end)
---   assert(not ok and err:find("without declaring it", 1, true))
--- <
---@param plugin string
---@param capabilities cds.needs.Capabilities
function M.strict(plugin, capabilities)
  local real = {}
  fp.each(modules(capabilities), function(name)
    local ok, mod = pcall(require, "cds." .. name)
    if ok then
      real[name] = mod
    end
  end)
  local present = fp.filter(modules(capabilities), function(name)
    return real[name] ~= nil
  end)
  fp.each(present, function(name)
    local allowed = fp.set(capabilities[name], function(fn)
      return fn
    end)
    package.loaded["cds." .. name] = setmetatable({}, {
      __index = function(_, key)
        if not allowed[key] and not in_library(debug.getinfo(INDEXER, "S")) then
          error(("%s uses cds.%s.%s without declaring it in its needs"):format(plugin, name, tostring(key)), INDEXER)
        end
        return real[name][key]
      end,
      __newindex = function(_, key, value)
        real[name][key] = value
      end,
    })
  end)
end

return require("cds.module").wrap("needs", M)
