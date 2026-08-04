-- End-to-end: drive real `/` and `?` over a hard-wrapped buffer.
--   nvim --headless -u NONE +"luafile tests/test_search.lua" +qa!

vim.opt.rtp:prepend(vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":h:h"))
require("wrapsearch").setup({ filetypes = true })

local fails, total = 0, 0
local function check(label, want_row, want_col)
  total = total + 1
  local pos = vim.api.nvim_win_get_cursor(0)
  if pos[1] ~= want_row or pos[2] ~= want_col then
    fails = fails + 1
    io.stderr:write(("FAIL %s\n  got  %s\n  want { %d, %d }\n")
      :format(label, vim.inspect(pos), want_row, want_col))
  end
end

-- A paragraph hard-wrapped mid-sentence, as latexmk-formatted prose tends to be.
local lines = {
  "Let $X$ be a scheme. The quick brown",
  "fox jumps over the lazy dog, and the",
  "    indented continuation follows it.",
  "unrelated tail",
  "a double  space, on one line.",
}
vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)

local function search(keys)
  vim.api.nvim_win_set_cursor(0, { 1, 0 })
  vim.api.nvim_feedkeys(vim.keycode(keys), "nx", false)
end

-- 1. A phrase split by the wrap: "brown" ends line 1, "fox" starts line 2.
search("/brown fox<CR>")
check("phrase across a hard wrap", 1, 31)

-- 2. Still works when the break is followed by indentation.
search("/the indented<CR>")
check("wrap followed by indentation", 2, 33)

-- 2a. A run of n spaces needs n whitespace characters, which a wrap plus a
-- four-space indent supplies exactly.
search("/the     indented<CR>")
check("five spaces span a wrap and its indent", 2, 33)

-- 2b. A very magic pattern needs the bare-quantifier spelling to be a valid
-- regex at all, so this fails loudly if the rewrite gets the mode wrong.
search([[/\vbrown fox<CR>]])
check("very magic across a hard wrap", 1, 31)

search([[/\vdouble  space<CR>]])
check("very magic run of spaces", 5, 2)

-- 3. A phrase entirely on one line is unaffected.
search("/quick brown<CR>")
check("phrase within one line", 1, 25)

-- 4. n keeps working: the rewritten pattern is in the search register.
search("/the<CR>")
vim.api.nvim_feedkeys(vim.keycode("n"), "nx", false)
total = total + 1
if vim.fn.getreg("/") ~= "the" then
  fails = fails + 1
  io.stderr:write("FAIL search register for a space-free pattern: " .. vim.fn.getreg("/") .. "\n")
end

-- 5. Backward search over a wrap.
vim.api.nvim_win_set_cursor(0, { 4, 0 })
vim.api.nvim_feedkeys(vim.keycode("?brown fox<CR>"), "nx", false)
check("backward across a hard wrap", 1, 31)

-- 6. The verbatim escape hatch does not rewrite. Fed with "m" so the mapping
-- is applied; "n" would bypass it and test nothing.
vim.api.nvim_win_set_cursor(0, { 1, 0 })
vim.api.nvim_feedkeys(vim.keycode("g/brown fox<CR>"), "mx", false)
total = total + 1
if vim.fn.getreg("/") ~= "brown fox" then
  fails = fails + 1
  io.stderr:write("FAIL g/ should search verbatim, register = " .. vim.fn.getreg("/") .. "\n")
end

-- 7. A search offset survives.
search("/brown fox/e<CR>")
total = total + 1
if not vim.fn.getreg("/"):find([[\_s\+]], 1, true) then
  fails = fails + 1
  io.stderr:write("FAIL offset form was not rewritten: " .. vim.fn.getreg("/") .. "\n")
end

-- 7a. Two spaces still mean two: they find a real double space...
search("/double  space<CR>")
check("double space matches a double space", 5, 2)

-- ...and do not match a single one.
search("/lazy  dog<CR>")
check("double space does not match a single space", 1, 0)

-- 8. Filetype gating: inactive filetypes are left alone.
require("wrapsearch").setup({ filetypes = { "tex" } })
vim.bo.filetype = "python"
search("/brown fox<CR>")
total = total + 1
if vim.fn.getreg("/") ~= "brown fox" then
  fails = fails + 1
  io.stderr:write("FAIL non-configured filetype was rewritten: " .. vim.fn.getreg("/") .. "\n")
end

io.stderr:write(("\n%d/%d passed\n"):format(total - fails, total))
if fails > 0 then vim.cmd("cq") end
