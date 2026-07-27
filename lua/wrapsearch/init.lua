--- wrapsearch.nvim
---
--- Hard-wrapped prose breaks search. A sentence that reads "the quick brown
--- fox" on screen is stored with a newline somewhere in the middle, so
--- `/quick brown` finds nothing when the wrap happens to fall between those
--- two words. This is a constant irritation in LaTeX, where hard wrapping is
--- the norm, and in any other hard-wrapped prose.
---
--- The fix is to rewrite the pattern just before the search runs: every
--- literal space also matches a line break plus the next line's indentation.
--- The search register receives the rewritten pattern, so `n` and `N` keep
--- working with no further help.

local pattern = require("wrapsearch.pattern")

local M = {}

---@class wrapsearch.Config
---@field filetypes? string[]|true Filetypes to act in, or `true` for all. Default: hard-wrapped prose filetypes.
---@field keys? boolean Install the `/` and `?` mappings. Default: true.
---@field literal_prefix? string|false Prefix that forces a verbatim search for one use. Default: `"g"`, giving `g/` and `g?`.
local defaults = {
  filetypes = { "tex", "latex", "plaintex", "markdown", "rst", "text", "typst", "mail", "gitcommit" },
  keys = true,
  literal_prefix = "g",
}

---@type wrapsearch.Config
M.config = vim.deepcopy(defaults)

--- One-shot escape hatch: set for the next search only, by the `g/` mapping.
local skip_once = false

--- Is the current buffer's filetype one we act in?
local function ft_active()
  local fts = M.config.filetypes
  if fts == true then return true end
  return vim.tbl_contains(fts or {}, vim.bo.filetype)
end

--- Rewrite the pending search pattern. Runs on CmdlineLeave, which is after
--- the user has committed the pattern but before Neovim executes it, so
--- `setcmdline()` here changes what actually runs.
local function on_cmdline_leave()
  local ctype = vim.fn.getcmdtype()
  if ctype ~= "/" and ctype ~= "?" then return end

  -- Consume the one-shot flag here rather than in the mapping. CmdlineLeave
  -- fires for an abandoned search too, so this cannot leak into the next one.
  local skip = skip_once
  skip_once = false
  if skip or not ft_active() then return end

  local line = vim.fn.getcmdline()
  local pat, offset = pattern.split_offset(line, ctype)
  local new, changed = pattern.rewrite(pat)
  if changed then
    vim.fn.setcmdline(new .. offset)
  end
end

--- Start a verbatim search, for when you do mean "exactly one space here".
---
--- An `expr` mapping rather than `nvim_feedkeys`: returning the key runs it in
--- the mapping's own position in the input stream, whereas feeding it would
--- queue it behind characters the user has already typed, so `g/foo` would run
--- `foo` as normal-mode commands and then open an empty prompt.
---@param key "/"|"?"
---@return string
local function literal_search(key)
  skip_once = true
  return key
end

---@param opts? wrapsearch.Config
function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", vim.deepcopy(defaults), opts or {})

  vim.api.nvim_create_autocmd("CmdlineLeave", {
    group = vim.api.nvim_create_augroup("wrapsearch", { clear = true }),
    pattern = { "/", "?" },
    callback = on_cmdline_leave,
  })

  local prefix = M.config.literal_prefix
  if M.config.keys and prefix then
    vim.keymap.set({ "n", "x" }, prefix .. "/", function() return literal_search("/") end,
      { expr = true, desc = "search (verbatim, ignore hard wraps)" })
    vim.keymap.set({ "n", "x" }, prefix .. "?", function() return literal_search("?") end,
      { expr = true, desc = "search backward (verbatim, ignore hard wraps)" })
  end
end

--- Rewrite a pattern by hand. Exposed for composing with other search UIs.
---@param pat string
---@return string
function M.rewrite(pat)
  return (pattern.rewrite(pat))
end

return M
