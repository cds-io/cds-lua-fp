---@tag cds-lua-fp
---@text
--- cds-lua-fp provides reusable list operations and error propagation for Lua
--- 5.1 and later, including LuaJIT and Neovim. It has no dependencies outside
--- the Lua standard library.
---
--- Use |cds.fp| to express transformations such as selecting records, extracting
--- fields, and removing duplicates without writing a loop for each operation.
--- Use |cds.result| to chain operations that return `value` or `nil, err` and
--- handle the first failure in one place. For plugins that share the library,
--- |cds.needs| checks required APIs at startup, and |cds.module| makes calls to
--- missing APIs report the module and name involved.
---
--- Install with `luarocks install cds-lua-fp`, or add
--- `{ "cds-io/cds-lua-fp", lazy = true }` to a lazy.nvim configuration.
--- The Neovim library cds-lua also declares it as a dependency.
---@toc

---@tag cds.fp
---@toc_entry Lists
---@text
--- Use these helpers when a loop's purpose is a standard list operation:
--- selecting, transforming, searching, or accumulating. Naming the operation
--- lets the callback focus on the application rule. They work in plain Lua
--- as well as Neovim.
---
--- For example, select enabled jobs and extract their names: >lua
---
---   local fp = require("cds.fp")
---   local jobs = {
---     { name = "build", enabled = true },
---     { name = "deploy", enabled = false },
---   }
---   local enabled = fp.filter(jobs, function(job) return job.enabled end)
---   local names = fp.map(enabled, function(job) return job.name end)
---   assert(#names == 1 and names[1] == "build")
---   assert(#jobs == 2) -- the input list is unchanged
--- <
--- Inputs are dense sequences indexed from 1: traversal uses `ipairs`, which
--- stops at the first missing index. Helpers do not mutate the input list;
--- returned records are the original objects, not deep copies. Callbacks may
--- still mutate those objects, so keep them pure when sharing input data.
---
--- Use `map` when every input produces a value, `filter_map` when some inputs
--- should be omitted, and |cds.result.traverse()| when a failed conversion
--- should reject the whole list. Callback arguments come last so multiline
--- functions sit directly below the operation they define.
---@class cds.fp
local M = {}

--- Transform every item while retaining its position. Use this to extract a
--- field or convert a list to another representation. A nil callback result
--- raises an error identifying the item: silently creating a hole would make
--- later `ipairs` loops stop early. False is a valid result.
---
--- >lua
---   local fp = require("cds.fp")
---   local names = fp.map({ { name = "Ada" }, { name = "Lin" } }, function(user)
---     return user.name
---   end)
---   assert(table.concat(names, ", ") == "Ada, Lin")
--- <
---@generic T, U
---@param list T[]
---@param fn fun(item: T, index: integer): U
---@return U[]
function M.map(list, fn)
  local out = {}
  for index, item in ipairs(list) do
    local mapped = fn(item, index)
    if mapped == nil then
      error("fp.map: the function returned nil for item " .. index, 2)
    end
    out[index] = mapped
  end
  return out
end

--- Select items without changing their order or representation. Keep an item
--- when `keep(item, index)` is truthy; return a fresh list of those items.
---
--- >lua
---   local fp = require("cds.fp")
---   local positive = fp.filter({ -1, 0, 2, 3 }, function(n) return n > 0 end)
---   assert(#positive == 2 and positive[1] == 2 and positive[2] == 3)
--- <
---@generic T
---@param list T[]
---@param keep fun(item: T, index: integer): any
---@return T[]
function M.filter(list, keep)
  local out = {}
  for index, item in ipairs(list) do
    if keep(item, index) then
      out[#out + 1] = item
    end
  end
  return out
end

--- Combine a list into one result, such as a total or lookup table. Start with
--- `initial`; each callback receives the previous accumulator, the item, and
--- its index. Return the final accumulator, or `initial` for an empty list.
---
--- >lua
---   local fp = require("cds.fp")
---   local total = fp.reduce({ 10, 20, 30 }, 0, function(sum, price)
---     return sum + price
---   end)
---   assert(total == 60)
---   assert(fp.reduce({}, 0, function() error("not called") end) == 0)
--- <
---@generic T, A
---@param list T[]
---@param initial A
---@param fn fun(value: A, item: T, index: integer): A
---@return A
function M.reduce(list, initial, fn)
  local value = initial
  for index, item in ipairs(list) do
    value = fn(value, item, index)
  end
  return value
end

--- Locate the first matching item without scanning the rest of the list.
--- Return the item and its index, or nil when no item matches. Test the index
--- or compare the item with nil: false can itself be a matching item.
---
--- >lua
---   local fp = require("cds.fp")
---   local item, index = fp.find({ true, false, true }, function(v)
---     return v == false
---   end)
---   assert(item == false and index == 2)
--- <
---@generic T
---@param list T[]
---@param test fun(item: T, index: integer): any
---@return T? item
---@return integer? index
function M.find(list, test)
  for index, item in ipairs(list) do
    if test(item, index) then
      return item, index
    end
  end
end

--- Try alternatives in order and return the first non-nil conversion. Use
--- this for parsers or lookup strategies where nil means "try the next one".
--- Stop immediately on a result, including false; return nil if none succeeds.
---
--- >lua
---   local fp = require("cds.fp")
---   local n = fp.find_map({ "unknown", "42", "99" }, function(text)
---     return tonumber(text)
---   end)
---   assert(n == 42)
--- <
---@generic T, U
---@param list T[]
---@param fn fun(item: T, index: integer): U?
---@return U?
function M.find_map(list, fn)
  for index, item in ipairs(list) do
    local found = fn(item, index)
    if found ~= nil then
      return found
    end
  end
end

--- Expand each item into zero or more items and concatenate the resulting
--- lists in input order. Use this when one record contributes several output
--- records; the callback must return a list, with `{}` contributing nothing.
---
--- >lua
---   local fp = require("cds.fp")
---   local files = fp.flat_map({ { "a.lua", "b.lua" }, {}, { "c.lua" } },
---     function(group) return group end)
---   assert(table.concat(files, ",") == "a.lua,b.lua,c.lua")
--- <
---@generic T, U
---@param list T[]
---@param fn fun(item: T, index: integer): U[]
---@return U[]
function M.flat_map(list, fn)
  local out = {}
  for index, item in ipairs(list) do
    for _, found in ipairs(fn(item, index)) do
      out[#out + 1] = found
    end
  end
  return out
end

--- Collect a table's keys so they can be filtered, sorted, or displayed.
--- Their order is unspecified because collection uses `pairs`; sort the result
--- when producing stable output.
---
--- >lua
---   local fp = require("cds.fp")
---   local names = fp.keys({ build = true, test = true })
---   table.sort(names)
---   assert(table.concat(names, ",") == "build,test")
--- <
---@generic K
---@param t table<K, any>
---@return K[]
function M.keys(t)
  local out = {}
  for key in pairs(t) do
    out[#out + 1] = key
  end
  return out
end

--- Perform an action for each item in order, ignoring callback return values.
--- Use this when the action matters and no output list is needed.
---
--- >lua
---   local fp = require("cds.fp")
---   local written = {}
---   fp.each({ "first", "second" }, function(line)
---     written[#written + 1] = line -- stand-in for an output sink
---   end)
---   assert(table.concat(written, "\n") == "first\nsecond")
--- <
---@generic T
---@param list T[]
---@param fn fun(item: T, index: integer)
function M.each(list, fn)
  for index, item in ipairs(list) do
    fn(item, index)
  end
end

--- Convert the items that are relevant and omit the rest in one pass. Keep
--- each non-nil callback result, including false, in input order. Use this
--- when an unsuccessful conversion should be skipped rather than fail the
--- whole operation.
---
--- >lua
---   local fp = require("cds.fp")
---   local numbers = fp.filter_map({ "10", "skip", "20" }, function(text)
---     return tonumber(text)
---   end)
---   assert(#numbers == 2 and numbers[1] == 10 and numbers[2] == 20)
--- <
---@generic T, U
---@param list T[]
---@param fn fun(item: T, index: integer): U?
---@return U[]
function M.filter_map(list, fn)
  local out = {}
  for index, item in ipairs(list) do
    local found = fn(item, index)
    if found ~= nil then
      out[#out + 1] = found
    end
  end
  return out
end

--- Check whether at least one item satisfies a condition. Stop at the first
--- truthy callback result; an empty list returns false.
---
--- >lua
---   local fp = require("cds.fp")
---   assert(fp.any({ 0, 5, 0 }, function(count) return count > 0 end))
---   assert(not fp.any({}, function() return true end))
--- <
---@generic T
---@param list T[]
---@param test fun(item: T, index: integer): any
---@return boolean
function M.any(list, test)
  for index, item in ipairs(list) do
    if test(item, index) then
      return true
    end
  end
  return false
end

--- Check whether every item satisfies a condition. Stop at the first falsy
--- callback result. An empty list returns true because no item violates the
--- condition; check the length separately if at least one item is required.
---
--- >lua
---   local fp = require("cds.fp")
---   assert(fp.all({ 2, 4 }, function(n) return n % 2 == 0 end))
---   assert(not fp.all({ 2, 3 }, function(n) return n % 2 == 0 end))
--- <
---@generic T
---@param list T[]
---@param test fun(item: T, index: integer): any
---@return boolean
function M.all(list, test)
  for index, item in ipairs(list) do
    if not test(item, index) then
      return false
    end
  end
  return true
end

--- Finds the key an item is filed under: key(item, index), or the item itself
--- without a key function. A nil key is an error, naming the item, since Lua
--- would refuse the nil index without saying which item gave it.
---@param name string                               -- the caller, for the message
---@param key? fun(item: any, index: integer): any
---@param item any
---@param index integer
---@return any
local function key_of(name, key, item, index)
  -- Spelled out: `key and key(item, index) or item` would fall back to
  -- the item on a nil key, which is the case to refuse.
  local found = item
  if key then
    found = key(item, index)
  end
  if found == nil then
    error("fp." .. name .. ": the key function returned nil for item " .. index, 3)
  end
  return found
end

--- Build a lookup table for repeated membership checks. Each item, or its
--- `key(item, index)`, becomes a table key with value true. Duplicate keys
--- collapse into one entry. A nil key raises an error identifying the item.
---
--- >lua
---   local fp = require("cds.fp")
---   local allowed = fp.set({ "read", "write", "read" })
---   assert(allowed.read and allowed.write and allowed.delete == nil)
--- <
---@generic T
---@param list T[]
---@param key? fun(item: T, index: integer): any   -- the item itself without one
---@return table<any, true>
function M.set(list, key)
  local out = {}
  for index, item in ipairs(list) do
    out[key_of("set", key, item, index)] = true
  end
  return out
end

--- Remove duplicates while preserving the first item for each key and its
--- position relative to other retained items. Supply `key` to compare records
--- by an identifier; without it, items themselves are the keys. A nil key
--- raises an error identifying the item.
---
--- >lua
---   local fp = require("cds.fp")
---   local records = { { id = "a", n = 1 }, { id = "a", n = 2 }, { id = "b" } }
---   local first = fp.unique(records, function(record) return record.id end)
---   assert(#first == 2 and first[1] == records[1] and first[2] == records[3])
--- <
---@generic T
---@param list T[]
---@param key? fun(item: T, index: integer): any   -- the item itself without one
---@return T[]
function M.unique(list, key)
  local seen, out = {}, {}
  for index, item in ipairs(list) do
    local found = key_of("unique", key, item, index)
    if not seen[found] then
      seen[found] = true
      out[#out + 1] = item
    end
  end
  return out
end

return require("cds.module").wrap("fp", M)
