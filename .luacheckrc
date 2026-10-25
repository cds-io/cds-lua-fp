-- the intersection of Lua 5.1 through 5.4: the rock runs on all of them
std = "min"
codes = true
max_line_length = 120
-- the specs name loadstring and load both, for whichever Lua runs them
files["spec/"] = { std = "max+busted" }
-- the help generator runs inside Neovim with mini.doc on the runtimepath
files["spec/minidoc.lua"] = { read_globals = { "vim", "MiniDoc" } }
