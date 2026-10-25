-- The language server behind `make site`: where the binary is, and the
-- configuration a run takes, the same Lua 5.1 pin as the committed .luarc.json.
local M = {}

--- The binary: LUALS when set, else the first of PATH and Mason's install
--- (Neovim's data directory, where :MasonInstall puts it) that has one; a
--- refusal in one line naming all three when none has it.
---@return string
function M.server()
  local mason = vim.fn.stdpath("data") .. "/mason/bin/lua-language-server"
  for _, candidate in ipairs({ vim.env.LUALS or "", vim.fn.exepath("lua-language-server"), mason }) do
    if candidate ~= "" and vim.fn.executable(candidate) == 1 then
      return candidate
    end
  end
  io.stderr:write(
    "no lua-language-server: LUALS is "
      .. (vim.env.LUALS or "unset")
      .. ", PATH has none, and Mason's "
      .. mason
      .. " is not there\n"
  )
  os.exit(1)
end

--- The repository's own .luarc.json: Lua 5.1, no library, spec/ left out.
---@return string path
function M.config()
  return M.root() .. "/.luarc.json"
end

--- The repository root: the parent of the directory this file is in.
---@return string
function M.root()
  return vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")
end

return M
