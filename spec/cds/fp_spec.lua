local fp = require("cds.fp")

describe("fp.map", function()
  it("gives each item's result, in order", function()
    assert.are.same(
      { 2, 4, 6 },
      fp.map({ 1, 2, 3 }, function(n)
        return n * 2
      end)
    )
  end)

  it("passes the item's index", function()
    assert.are.same(
      { "1:a", "2:b" },
      fp.map({ "a", "b" }, function(item, index)
        return index .. ":" .. item
      end)
    )
  end)

  it("keeps a false result as an item", function()
    assert.are.same(
      { false, true },
      fp.map({ 1, 2 }, function(n)
        return n > 1
      end)
    )
  end)

  it("gives an empty list for an empty list", function()
    assert.are.same(
      {},
      fp.map({}, function()
        error("called")
      end)
    )
  end)

  it("returns a new list and leaves its own alone", function()
    local list = { 1, 2 }
    local mapped = fp.map(list, function(n)
      return n
    end)
    assert.are_not.equal(list, mapped)
    assert.are.same({ 1, 2 }, list)
  end)

  it("refuses a nil result, which would leave a hole in the list", function()
    local ok, err = pcall(fp.map, { "a", "b", "c" }, function(item)
      return item ~= "b" and item or nil
    end)
    assert.is_false(ok)
    assert.is_truthy(err:find("fp.map: the function returned nil for item 2", 1, true), err)
  end)
end)

describe("fp.filter", function()
  it("keeps the items the test accepts, in order and without holes", function()
    local even = fp.filter({ 1, 2, 3, 4, 5, 6 }, function(n)
      return n % 2 == 0
    end)
    assert.are.same({ 2, 4, 6 }, even)
    assert.are.equal(3, #even)
  end)

  it("passes the item's index", function()
    assert.are.same(
      { "a", "c" },
      fp.filter({ "a", "b", "c" }, function(_, index)
        return index ~= 2
      end)
    )
  end)

  it("keeps an item that is false when the test accepts it", function()
    assert.are.same(
      { false },
      fp.filter({ false, true }, function(item)
        return item == false
      end)
    )
  end)

  it("gives an empty list when nothing passes, or nothing was given", function()
    assert.are.same(
      {},
      fp.filter({ 1, 2 }, function()
        return false
      end)
    )
    assert.are.same(
      {},
      fp.filter({}, function()
        error("called")
      end)
    )
  end)

  it("returns a new list and leaves its own alone", function()
    local list = { 1, 2 }
    local kept = fp.filter(list, function()
      return true
    end)
    assert.are_not.equal(list, kept)
    assert.are.same({ 1, 2 }, list)
  end)
end)

describe("fp.reduce", function()
  it("folds the items into the initial value, left to right", function()
    assert.are.equal(
      10,
      fp.reduce({ 1, 2, 3, 4 }, 0, function(sum, n)
        return sum + n
      end)
    )
    assert.are.equal(
      "-abc",
      fp.reduce({ "a", "b", "c" }, "-", function(text, item)
        return text .. item
      end)
    )
  end)

  it("passes the item's index", function()
    assert.are.equal(
      3,
      fp.reduce({ "a", "b", "c" }, 0, function(_, _, index)
        return index
      end)
    )
  end)

  it("gives the initial value back for an empty list", function()
    local initial = {}
    assert.are.equal(
      initial,
      fp.reduce({}, initial, function()
        error("called")
      end)
    )
  end)

  it("builds any kind of value, a table included", function()
    local seen = fp.reduce({ "a", "b" }, {}, function(set, item)
      set[item] = true
      return set
    end)
    assert.are.same({ a = true, b = true }, seen)
  end)
end)

describe("fp.find", function()
  it("gives the first item the test accepts, and its index", function()
    assert.are.same({ "b", 2 }, {
      fp.find({ "a", "b", "c" }, function(item)
        return item ~= "a"
      end),
    })
  end)

  it("passes the item's index", function()
    assert.are.same({ "c", 3 }, {
      fp.find({ "a", "b", "c" }, function(_, index)
        return index == 3
      end),
    })
  end)

  it("gives nil when nothing passes, or nothing was given", function()
    assert.is_nil(fp.find({ 1, 2 }, function()
      return false
    end))
    assert.is_nil(fp.find({}, function()
      error("called")
    end))
  end)

  it("stops at the first match", function()
    local asked = 0
    fp.find({ 1, 2, 3 }, function(n)
      asked = asked + 1
      return n == 2
    end)
    assert.are.equal(2, asked)
  end)
end)

describe("fp.any", function()
  it("is true when some item passes, and stops there", function()
    local asked = 0
    assert.is_true(fp.any({ 1, 2, 3 }, function(n)
      asked = asked + 1
      return n == 2
    end))
    assert.are.equal(2, asked)
  end)

  it("is false when no item passes, and for an empty list", function()
    assert.is_false(fp.any({ 1, 2 }, function()
      return false
    end))
    assert.is_false(fp.any({}, function()
      error("called")
    end))
  end)

  it("passes the item's index", function()
    assert.is_true(fp.any({ "a", "b" }, function(_, index)
      return index == 2
    end))
  end)
end)

describe("fp.all", function()
  it("is true when every item passes, and for an empty list", function()
    assert.is_true(fp.all({ 2, 4 }, function(n)
      return n % 2 == 0
    end))
    assert.is_true(fp.all({}, function()
      error("called")
    end))
  end)

  it("is false at the first item that fails, and stops there", function()
    local asked = 0
    assert.is_false(fp.all({ 2, 3, 4 }, function(n)
      asked = asked + 1
      return n % 2 == 0
    end))
    assert.are.equal(2, asked)
  end)

  it("passes the item's index", function()
    assert.is_true(fp.all({ "a", "b" }, function(item, index)
      return item == ("ab"):sub(index, index)
    end))
  end)
end)

describe("fp.set", function()
  it("marks each item true, keyed by itself", function()
    assert.are.same({ a = true, b = true }, fp.set({ "a", "b", "a" }))
  end)

  it("keys by the function when given one, passing the index", function()
    assert.are.same(
      { A = true, B = true },
      fp.set({ "a", "b" }, function(item)
        return item:upper()
      end)
    )
    assert.are.same(
      { [1] = true, [2] = true },
      fp.set({ "a", "b" }, function(_, index)
        return index
      end)
    )
  end)

  it("is empty for an empty list, and leaves the list alone", function()
    local list = { "a" }
    assert.are.same(
      {},
      fp.set({}, function()
        error("called")
      end)
    )
    fp.set(list)
    assert.are.same({ "a" }, list)
  end)

  it("refuses a nil key, naming the item", function()
    local ok, err = pcall(fp.set, { "a", "b" }, function(item)
      return item ~= "b" and item or nil
    end)
    assert.is_false(ok)
    assert.is_truthy(err:find("fp.set: the key function returned nil for item 2", 1, true), err)
  end)
end)

describe("fp.unique", function()
  it("keeps the first of each item, in order", function()
    assert.are.same({ "b", "a", "c" }, fp.unique({ "b", "a", "b", "c", "a" }))
  end)

  it("keeps the first of each key when given a key function, passing the index", function()
    assert.are.same(
      { "Ab", "cd" },
      fp.unique({ "Ab", "aB", "cd" }, function(item)
        return item:lower()
      end)
    )
    assert.are.same(
      { 1, 2 },
      fp.unique({ 1, 2, 3, 4 }, function(_, index)
        return index % 2
      end)
    )
  end)

  it("gives an empty list for an empty list, and a new list otherwise", function()
    assert.are.same(
      {},
      fp.unique({}, function()
        error("called")
      end)
    )
    local list = { "a", "a" }
    local kept = fp.unique(list)
    assert.are_not.equal(list, kept)
    assert.are.same({ "a", "a" }, list)
  end)

  it("refuses a nil key, naming the item", function()
    local ok, err = pcall(fp.unique, { "a", "b" }, function(item)
      return item ~= "b" and item or nil
    end)
    assert.is_false(ok)
    assert.is_truthy(err:find("fp.unique: the key function returned nil for item 2", 1, true), err)
  end)
end)

describe("fp", function()
  it("chains: the evens, times ten, summed", function()
    local evens = fp.filter({ 1, 2, 3, 4 }, function(n)
      return n % 2 == 0
    end)
    local tens = fp.map(evens, function(n)
      return n * 10
    end)
    assert.are.equal(
      60,
      fp.reduce(tens, 0, function(sum, n)
        return sum + n
      end)
    )
  end)
end)

describe("fp.flat_map", function()
  it("joins the lists the function answers, in order", function()
    assert.are.same(
      { 1, 1, 2, 2 },
      fp.flat_map({ 1, 2 }, function(item)
        return { item, item }
      end)
    )
  end)

  it("drops an item whose answer is empty, and passes the index", function()
    assert.are.same(
      { "b2" },
      fp.flat_map({ "a", "b" }, function(item, index)
        return index == 2 and { item .. index } or {}
      end)
    )
  end)
end)

describe("fp.keys", function()
  it("answers every key once, in some order", function()
    local keys = fp.keys({ b = 1, a = 2 })
    table.sort(keys)
    assert.are.same({ "a", "b" }, keys)
    assert.are.same({}, fp.keys({}))
  end)
end)

describe("fp.each", function()
  it("calls fn with each item and its index, in order, and answers nothing", function()
    local seen = {}
    local answer = fp.each({ "a", "b" }, function(item, index)
      seen[#seen + 1] = item .. index
      return "dropped"
    end)
    assert.are.same({ "a1", "b2" }, seen)
    assert.is_nil(answer)
  end)

  it("does nothing for an empty list", function()
    local called = false
    fp.each({}, function()
      called = true
    end)
    assert.is_false(called)
  end)
end)

describe("fp.filter_map", function()
  it("keeps every non-nil answer, in order", function()
    assert.are.same(
      { 2, 3 },
      fp.filter_map({ "a", "2", "b", "3" }, function(item)
        return tonumber(item)
      end)
    )
  end)

  it("keeps a false answer, since only nil means no answer", function()
    assert.are.same(
      { false },
      fp.filter_map({ 1 }, function()
        return false
      end)
    )
  end)

  it("passes the index, and answers an empty list for one", function()
    assert.are.same(
      { "b2" },
      fp.filter_map({ "a", "b" }, function(item, index)
        return index == 2 and item .. index or nil
      end)
    )
    assert.are.same(
      {},
      fp.filter_map({}, function(item)
        return tonumber(item)
      end)
    )
  end)
end)

describe("fp.find_map", function()
  it("gives the first non-nil answer, and stops there", function()
    local asked = 0
    local found = fp.find_map({ "a", "2", "3" }, function(item)
      asked = asked + 1
      return tonumber(item)
    end)
    assert.are.equal(2, found)
    assert.are.equal(2, asked)
  end)

  it("keeps a false answer, since only nil means no answer", function()
    assert.is_false(fp.find_map({ 1 }, function()
      return false
    end))
  end)

  it("passes the item's index", function()
    assert.are.equal(
      "2:b",
      fp.find_map({ "a", "b" }, function(item, index)
        return index == 2 and index .. ":" .. item or nil
      end)
    )
  end)

  it("gives nil when every item answers nil, or nothing was given", function()
    assert.is_nil(fp.find_map({ 1, 2 }, function()
      return nil
    end))
    assert.is_nil(fp.find_map({}, function()
      error("called")
    end))
  end)
end)

describe("fp.memoize", function()
  local calls, fn
  before_each(function()
    calls = 0
    fn = function(a, b)
      calls = calls + 1
      return a .. ":" .. tostring(b), "note"
    end
  end)

  it("remembers one answer per slot, the first argument unless told, and gives every value back", function()
    local m = fp.memoize(fn)
    local value, note = m("a", 1)
    assert.are.equal("a:1", value)
    assert.are.equal("note", note)
    assert.are.equal("a:1", m("a", 2))
    assert.are.equal(1, calls)
    assert.are.equal("b:3", m("b", 3))
    assert.are.equal(2, calls)
  end)

  it("keeps the answer while the key matches and computes again when it changes", function()
    local revision = { a = 1 }
    local m = fp.memoize(fn, {
      key = function(path)
        return revision[path]
      end,
    })
    assert.are.equal("a:1", m("a", 1))
    assert.are.equal("a:1", m("a", 2))
    revision.a = 2
    assert.are.equal("a:3", m("a", 3))
    assert.are.equal(2, calls)
  end)

  it("takes the slot from a function of the arguments", function()
    local m = fp.memoize(fn, {
      slot = function(a, b)
        return a .. "/" .. b
      end,
    })
    m("a", 1)
    m("a", 1)
    m("a", 2)
    assert.are.equal(2, calls)
  end)

  it("does not remember a failure, nor an answer keep refuses", function()
    local answers = { nil, "x", "y" }
    local i = 0
    local m = fp.memoize(function()
      i = i + 1
      return answers[i], i == 1 and "failed" or nil
    end)
    local value, err = m("slot")
    assert.is_nil(value)
    assert.are.equal("failed", err)
    assert.are.equal("x", m("slot"))
    assert.are.equal("x", m("slot"))
    assert.are.equal(2, i)
    local waiting = true
    local n = 0
    local k = fp.memoize(function()
      n = n + 1
      return "lines", waiting
    end, {
      keep = function(_, still_waiting)
        return not still_waiting
      end,
    })
    k("s")
    k("s")
    assert.are.equal(2, n)
    waiting = false
    k("s")
    k("s")
    assert.are.equal(3, n)
  end)

  it("says what it holds and forgets on request", function()
    local m, memo = fp.memoize(fn)
    assert.is_false(memo.held("a"))
    m("a", 1)
    assert.is_true(memo.held("a"))
    memo.forget()
    assert.is_false(memo.held("a"))
    m("a", 1)
    assert.are.equal(2, calls)
  end)

  it("slots a table by identity", function()
    local m = fp.memoize(function(t)
      calls = calls + 1
      return t.v
    end)
    local one, two = { v = 1 }, { v = 2 }
    assert.are.equal(1, m(one))
    assert.are.equal(1, m(one))
    assert.are.equal(2, m(two))
    assert.are.equal(2, calls)
  end)
end)
