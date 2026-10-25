---@tag cds.result
---@toc_entry The Result convention
---@text
--- Use `result` when several operations can fail and later operations need the
--- previous result. It carries the first error past the remaining steps, so
--- you can handle failure once instead of repeating a check after every call.
--- It uses ordinary Lua return values: `value` for success, `nil, err` for
--- failure. There is no Result object to construct or unwrap.
---
--- For example, parse a setting, validate it, then format it for display: >lua
---
---   local result = require("cds.result")
---   local function parse(text)
---     local n = tonumber(text)
---     if n == nil then return nil, "expected a number" end
---     return n
---   end
---   local function positive(n)
---     if n <= 0 then return nil, "must be positive" end
---     return n
---   end
---   local function label(text)
---     local value, err = parse(text)
---     value, err = result.bind(value, err, positive)
---     return result.map(value, err, function(n)
---       return "Retries: " .. n
---     end)
---   end
---
---   assert(label("3") == "Retries: 3")
---   local value, err = label("oops")
---   assert(value == nil and err == "expected a number")
---   -- Neither positive nor the formatting callback runs on this failure.
--- <
--- Choose `bind` for a callback that can return `nil, err`; choose `map` for
--- one that produces a non-nil value. Use `traverse` to validate or transform
--- a whole list when any failed item should reject the result. For a list
--- transformation with no error propagation, use |cds.fp.map()|.
---
--- Only nil signals failure: false and zero are successful values. These
--- helpers do not catch thrown errors; callbacks must return expected failures
--- as `nil, err`. The caller decides whether to display, log, or return the
--- final error.
---
--- Keep both return values in locals before passing them to `bind` or `map`.
--- Lua keeps only the first return value of a call followed by more arguments:
--- `result.bind(parse(text), nil, positive)` would discard the parse error.
---@class cds.result
local M = {}

--- Run the next fallible step only if the previous step succeeded. On failure,
--- return `nil, err` unchanged without calling `fn`; on success, return what
--- `fn(value)` returns. This prevents later steps from acting on missing data.
---
--- >lua
---   local result = require("cds.result")
---   local called = false
---   local value, err = result.bind(nil, "file not found", function(text)
---     called = true
---     return text:upper()
---   end)
---   assert(value == nil and err == "file not found" and not called)
--- <
---@generic T, U
---@param value T?
---@param err any
---@param fn fun(value: T): U?, any
---@return U? value
---@return any err
function M.bind(value, err, fn)
  if value == nil then
    return nil, err
  end
  return fn(value)
end

--- Transform a successful value while preserving an earlier failure. Use this
--- name when the callback has no expected failure case, such as formatting a
--- validated number. It is an alias of `bind`: this distinction documents the
--- callback's intent, and is not enforced at runtime.
---
--- >lua
---   local result = require("cds.result")
---   local value, err = result.map(false, nil, tostring)
---   assert(value == "false" and err == nil)
--- <
M.map = M.bind

--- Add the location or operation that makes an error actionable. A parser may
--- know what went wrong but not which setting it was parsing; its caller can
--- add that information without changing the successful value. On failure,
--- `err` must be a string; include any separator in `prefix`.
---
--- >lua
---   local result = require("cds.result")
---   local value, err = result.context(nil, "expected a number", "retries: ")
---   assert(value == nil and err == "retries: expected a number")
---   assert(result.context(3, nil, "retries: ") == 3)
--- <
---@generic T
---@param value T?
---@param err string?
---@param prefix string
---@return T? value
---@return string? err
function M.context(value, err, prefix)
  if value == nil then
    return nil, prefix .. err
  end
  return value
end

--- Build a list only if every item can be transformed successfully. Call
--- `fn(value, index)` in order and stop at the first nil result, returning
--- `nil, err` instead of a partial list. An empty input succeeds with `{}`.
--- Earlier callback effects are not undone; use pure callbacks when a failed
--- batch must leave nothing changed.
---
--- >lua
---   local result = require("cds.result")
---   local function number(text, i)
---     local n = tonumber(text)
---     if n == nil then return nil, "item " .. i .. ": expected a number" end
---     return n
---   end
---   local values = assert(result.traverse({ "10", "20" }, number))
---   assert(values[1] == 10 and values[2] == 20)
---   local value, err = result.traverse({ "10", "bad", "30" }, number)
---   assert(value == nil and err == "item 2: expected a number")
--- <
---@generic T, U
---@param values T[]
---@param fn fun(value: T, index: integer): U?, any
---@return U[]? values
---@return any err
function M.traverse(values, fn)
  local out = {}
  for i, value in ipairs(values) do
    local mapped, err = fn(value, i)
    if mapped == nil then
      return nil, err
    end
    out[i] = mapped
  end
  return out
end

return require("cds.module").wrap("result", M)
