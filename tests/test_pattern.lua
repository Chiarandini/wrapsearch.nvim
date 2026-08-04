-- Unit tests for the pattern rewriter.
--   nvim --headless -u NONE +"lua vim.opt.rtp:prepend('.')" +"luafile tests/test_pattern.lua" +qa!

vim.opt.rtp:prepend(vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":h:h"))
local P = require("wrapsearch.pattern")

local fails, total = 0, 0
local function eq(got, want, label)
  total = total + 1
  if got ~= want then
    fails = fails + 1
    io.stderr:write(("FAIL %s\n  got  %s\n  want %s\n"):format(label, vim.inspect(got), vim.inspect(want)))
  end
end

local J = P.JOIN

-- ── rewrite ──────────────────────────────────────────────────────────
eq(P.rewrite("brown fox"),        "brown" .. J .. "fox",        "single space")
eq(P.rewrite("a b c"),            "a" .. J .. "b" .. J .. "c",  "several spaces")
eq(P.rewrite("nospace"),          "nospace",                     "no space is untouched")
eq(P.rewrite("two  spaces"),      [[two\_s\{2,}spaces]],         "a run of two keeps requiring two")
eq(P.rewrite("wide   gap"),       [[wide\_s\{3,}gap]],           "a longer run counts")
eq(P.rewrite("  "),               [[\_s\{2,}]],                  "nothing but spaces")
eq(select(2, P.rewrite("plain")), false,                         "unchanged reports false")
eq(select(2, P.rewrite("a b")),   true,                          "changed reports true")

-- Regex constructs must survive.
eq(P.rewrite([[[a b]x]]),         [[[a b]x]],                    "space inside a collection")
eq(P.rewrite([[a\ b]]),           [[a\ b]],                      "explicitly escaped space")
eq(P.rewrite([[\<the\> cat]]),    [[\<the\>]] .. J .. "cat",     "word boundaries")
eq(P.rewrite([[x\{2,3} y]]),      [[x\{2,3}]] .. J .. "y",       "quantifier then space")
eq(P.rewrite([[\Vfoo bar]]),      [[\Vfoo]] .. J .. "bar",       "very nomagic prefix")
eq(P.rewrite([[foo\_sbar]]),      [[foo\_sbar]],                 "existing \\_s untouched")
eq(P.rewrite([[a[ ]b c]]),        [[a[ ]b]] .. J .. "c",         "collection then real space")
eq(P.rewrite([[a\  b]]),          [[a\ ]] .. J .. "b",           "escaped space then a real one")

-- ── magic modes ──────────────────────────────────────────────────────
-- Under \v the quantifiers are bare: `\+` would be a literal plus sign.
eq(P.rewrite([[\vbrown fox]]),    [[\vbrown\_s+fox]],            "very magic single space")
eq(P.rewrite([[\vtwo  spaces]]),  [[\vtwo\_s{2,}spaces]],        "very magic run of spaces")
eq(P.rewrite([[\va b\mc d]]),     [[\va\_s+b\mc]] .. J .. "d",   "mode switch mid-pattern")
eq(P.rewrite([[a b\vc d]]),       "a" .. J .. [[b\vc\_s+d]],     "magic until \\v appears")
eq(P.rewrite([[\vx{2,3} y]]),     [[\vx{2,3}\_s+y]],             "very magic quantifier is bare")
eq(P.rewrite([[\v[a b]x y]]),     [[\v[a b]x\_s+y]],             "very magic collection")
-- Under \M and \V a collection needs `\[`; a bare `[` is just a character.
eq(P.rewrite([[\M\[a b]x]]),      [[\M\[a b]x]],                 "nomagic collection")
eq(P.rewrite("\\Mfoo[a b]"),      [[\Mfoo[a]] .. J .. "b]",      "nomagic bare bracket is literal")
eq(P.rewrite([[\V\[a b]x y]]),    [[\V\[a b]x]] .. J .. "y",     "very nomagic collection")

-- ── split_offset ─────────────────────────────────────────────────────
local function so(s, sep) local a, b = P.split_offset(s, sep); return a .. "||" .. b end
eq(so("foo bar", "/"),            "foo bar||",                   "no offset")
eq(so("foo/e", "/"),              "foo||/e",                     "offset e")
eq(so("foo/+2", "/"),             "foo||/+2",                    "offset +2")
eq(so([[a\/b/e]], "/"),           [[a\/b||/e]],                  "escaped separator is not the offset")
eq(so("foo?e", "?"),              "foo||?e",                     "backward search offset")
eq(so("a/b", "?"),                "a/b||",                       "wrong separator is literal")

-- ── end-to-end through the offset split, as the autocmd does it ──────
local line, sep = "quick brown/e", "/"
local pat, off = P.split_offset(line, sep)
eq(P.rewrite(pat) .. off, "quick" .. J .. "brown/e", "offset preserved through rewrite")

io.stderr:write(("\n%d/%d passed\n"):format(total - fails, total))
if fails > 0 then vim.cmd("cq") end
