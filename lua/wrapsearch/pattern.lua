--- Pattern rewriting: make literal spaces in a search pattern also match a
--- line break plus the next line's indentation.
---
--- The transformation is textual and deliberately conservative. A space is
--- only rewritten when it is a plain literal: not escaped, not inside a `[]`
--- collection, and not inside a `\{...}` quantifier. Everything else in the
--- pattern is copied through untouched, so a pattern that already works keeps
--- working.
---
--- A pattern may switch magic mode part way through with `\v`, `\m`, `\M` or
--- `\V`, and that changes both what the replacement has to look like and what
--- counts as a collection or a quantifier, so the mode is tracked as we go.

local M = {}

--- What a run of literal spaces is replaced with.
---
--- `\_s` is "whitespace or newline"; `\+` is one or more. Together they span
--- the line break and whatever indentation the next line carries, which is
--- exactly what a hard wrap inserts.
M.JOIN = [[\_s\+]]

--- What a run of `n` literal spaces is replaced with: at least `n` whitespace
--- characters, so `/  ` keeps meaning two spaces and does not match one. A
--- wrap can still supply them, as a line break plus the next line's indent.
---
--- Under `\v` the quantifiers are spelled bare: there, `\+` is a literal plus
--- and `\{` a literal brace, so the magic spelling would search for the
--- punctuation instead of repeating anything.
---@param n integer
---@param very_magic? boolean
---@return string
function M.join(n, very_magic)
  if very_magic then
    return n == 1 and [[\_s+]] or ([[\_s{%d,}]]):format(n)
  end
  return n == 1 and M.JOIN or ([[\_s\{%d,}]]):format(n)
end

--- Split a `/pattern/offset` command line into its two halves.
---
--- Vim allows a trailing offset after an unescaped separator (`/foo/e`,
--- `/foo/+2`). Rewriting inside the offset would corrupt it, so it is carved
--- off first and reattached afterwards.
---@param cmdline string  the text of the search command line, without the leading / or ?
---@param sep string      "/" or "?"
---@return string pattern
---@return string offset  including its leading separator, or ""
function M.split_offset(cmdline, sep)
  local i, n = 1, #cmdline
  while i <= n do
    local c = cmdline:sub(i, i)
    if c == "\\" then
      i = i + 2
    elseif c == sep then
      return cmdline:sub(1, i - 1), cmdline:sub(i)
    else
      i = i + 1
    end
  end
  return cmdline, ""
end

--- Rewrite literal spaces in `pat` so they also match across a hard wrap.
---
--- Returns the pattern unchanged when there is nothing to do, which lets the
--- caller skip `setcmdline()` entirely and leave the command line alone.
---@param pat string
---@return string rewritten
---@return boolean changed
function M.rewrite(pat)
  local out, i, n = {}, 1, #pat
  local in_class = false      -- inside [...]
  local in_brace = false      -- inside a {n,m} quantifier
  local mode = "m"            -- magic mode in force here: v, m, M or V
  local changed = false

  while i <= n do
    local c = pat:sub(i, i)
    -- Under \v a quantifier is a bare `{`; elsewhere it is `\{`. Under \M and
    -- \V a collection opens with `\[`; elsewhere with a bare `[`.
    local very_magic = mode == "v"
    local bare_class = mode == "v" or mode == "m"

    if c == "\\" then
      -- Copy the escape and whatever it escapes as one unit, so `\ ` (an
      -- explicitly literal space) and `\_s` survive untouched.
      local nxt = pat:sub(i + 1, i + 1)
      if not in_class then
        if nxt == "v" or nxt == "m" or nxt == "M" or nxt == "V" then
          mode = nxt
        elseif nxt == "{" and not very_magic then
          in_brace = true
        elseif nxt == "[" and not bare_class and not in_brace then
          in_class = true
        end
      end
      out[#out + 1] = pat:sub(i, i + 1)
      i = i + 2
    elseif c == "{" and very_magic and not in_class and not in_brace then
      in_brace = true
      out[#out + 1] = c
      i = i + 1
    elseif c == "}" and in_brace then
      -- However it opened, a quantifier closes with a bare `}`.
      in_brace = false
      out[#out + 1] = c
      i = i + 1
    elseif c == "[" and bare_class and not in_class and not in_brace then
      in_class = true
      out[#out + 1] = c
      i = i + 1
    elseif c == "]" and in_class then
      in_class = false
      out[#out + 1] = c
      i = i + 1
    elseif c == " " and not in_class and not in_brace then
      local j = i
      while pat:sub(j, j) == " " do j = j + 1 end
      out[#out + 1] = M.join(j - i, very_magic)
      changed = true
      i = j
    else
      out[#out + 1] = c
      i = i + 1
    end
  end

  return table.concat(out), changed
end

return M
