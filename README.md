# wrapsearch.nvim

Search across hard-wrapped lines.

Hard-wrapped prose breaks search. This paragraph:

```tex
Let $X$ be a scheme. The quick brown
fox jumps over the lazy dog.
```

has a newline between `brown` and `fox`, so `/brown fox` finds nothing. You
end up guessing where the wrap fell and searching for a fragment instead.

wrapsearch rewrites the pattern just before the search runs, so a literal
space also matches a line break and the next line's indentation. `/brown fox`
finds the phrase. `n`, `N`, search offsets, the search register and match
highlighting all behave as usual, because the rewritten pattern is what Neovim
actually searches for.

## Install

```lua
{ "Chiarandini/wrapsearch.nvim", ft = { "tex", "markdown" }, opts = {} }
```

## Configuration

```lua
require("wrapsearch").setup({
    -- Filetypes to act in, or true for every buffer.
    filetypes = { "tex", "latex", "plaintex", "markdown", "rst", "text",
                  "typst", "mail", "gitcommit" },
    -- Install the verbatim-search mappings.
    keys = true,
    -- Prefix for them, giving g/ and g?. false installs nothing.
    literal_prefix = "g",
})
```

The default filetype list covers what is usually hard wrapped. In code a space
in a pattern normally means a space, so acting everywhere would be surprising.

`/` and `?` are never remapped: the rewriting happens in a `CmdlineLeave`
autocommand, so whatever else you have bound to those keys keeps working.

## Searching verbatim

When a space really does mean a space, `g/` and `g?` search without rewriting,
for one search.

## What is and is not rewritten

Runs of literal spaces become `\_s\+`. Everything else is copied through, so a
pattern that already works keeps working:

| Pattern | Result |
|---|---|
| `brown fox` | `brown\_s\+fox` |
| `[a b]x` | unchanged, space is inside a collection |
| `a\ b` | unchanged, you escaped it yourself |
| `x\{2,3} y` | `x\{2,3}\_s\+y`, the quantifier is left alone |
| `brown fox/e` | offset split off, reattached after rewriting |

## Limitations

`incsearch` previews the pattern you typed, not the rewritten one, because the
rewrite happens on `<CR>`. A phrase spanning a wrap shows no preview and then
jumps correctly. Search history stores the rewritten form.

Only interactive searches are rewritten: `vim.fn.search()` and a pattern typed
as an Ex command are unaffected. `require("wrapsearch").rewrite(pat)` opts
those in by hand.

A comment leader at the start of a continuation line is not skipped, so a
phrase spanning a `%`-commented line in LaTeX is not found.

See `:help wrapsearch` for the rest.

## Tests

```bash
nvim --headless -u NONE +"luafile tests/test_pattern.lua" +qa!
nvim --headless -u NONE +"luafile tests/test_search.lua"  +qa!
```
