-- The rock as a lazy.nvim plugin: lua/cds/ on the runtimepath, loaded on its
-- first require. cds-lua declares it as a dependency, so a plugin that takes
-- cds-lua gets it; a plugin that needs only the vocabulary declares it alone.
return { "cds-io/cds-lua-fp", lazy = true }
