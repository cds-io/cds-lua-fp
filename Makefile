# busted for Lua 5.1, the interpreter Neovim's LuaJIT shares its ABI with;
# the luarocks user tree is where `luarocks --lua-version=5.1 install --local
# busted` puts it. CI runs the specs on 5.1, 5.4 and LuaJIT.
BUSTED ?= $(if $(wildcard $(HOME)/.luarocks/bin/busted),$(HOME)/.luarocks/bin/busted,busted)
STYLUA ?= stylua
LUACHECK ?= luacheck
# the language server: on PATH, or Mason's install under Neovim's data directory
LUALS ?= $(if $(shell command -v lua-language-server 2>/dev/null),lua-language-server,$(HOME)/.local/share/nvim/mason/bin/lua-language-server)
NVIM ?= nvim
# mini.doc generates doc/cds-lua-fp.txt from the annotation blocks: the
# standalone nvim-mini/mini.doc beside this checkout (CI), or the mini.nvim
# lazy installed, which carries it.
MINIDOC ?= $(firstword $(wildcard ../mini.doc $(HOME)/.local/share/nvim/lazy/mini.doc $(HOME)/.local/share/nvim/lazy/mini.nvim))

.PHONY: all check test lint typecheck doc doc-check site

all: check

check: test lint doc-check ## what CI would run

test: ## the specs under plain busted
	$(BUSTED)

lint: ## stylua, luacheck and the language server's type check
	$(STYLUA) --check lua spec
	$(LUACHECK) lua spec
	$(MAKE) typecheck
	$(MAKE) site

# .luarc.json pins Lua 5.1, the lowest version the rock runs on, so the
# check holds for every version above it.
typecheck: ## lua-language-server --check over lua/, warnings fail
	$(LUALS) --check . --configpath .luarc.json --checklevel Warning

doc: ## doc/cds-lua-fp.txt from the annotation blocks, with mini.doc
	$(NVIM) --headless -u NONE -i NONE --cmd "set rtp+=$(MINIDOC)" -l spec/minidoc.lua

doc-check: doc ## the committed help file is current
	git diff --exit-code -- doc/cds-lua-fp.txt

# The reference site's module pages, from the language server's export of the
# annotations; the Pages workflow builds site/ with Jekyll on every push to
# main. site/modules/ is generated and stays out of git.
site: ## site/modules/*.md, one page per module
	$(NVIM) --headless -u NONE -i NONE -l spec/site.lua
