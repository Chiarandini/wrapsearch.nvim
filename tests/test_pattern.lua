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
eq(P.rewrite("two  spaces"),      "two" .. J .. "spaces",        "a run collapses to one join")
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
