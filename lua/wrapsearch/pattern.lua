--- Pattern rewriting: make literal spaces in a search pattern also match a
--- line break plus the next line's indentation.
---
--- The transformation is textual and deliberately conservative. A space is
--- only rewritten when it is a plain literal: not escaped, not inside a `[]`
--- collection, and not inside a `\{...}` quantifier. Everything else in the
--- pattern is copied through untouched, so a pattern that already works keeps
--- working.

local M = {}

--- What a run of literal spaces is replaced with.
---
--- `\_s` is "whitespace or newline"; `\+` is one or more. Together they span
--- the line break and whatever indentation the next line carries, which is
--- exactly what a hard wrap inserts.
M.JOIN = [[\_s\+]]

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
  local in_brace = false      -- inside \{...}
  local changed = false

  while i <= n do
    local c = pat:sub(i, i)

    if c == "\\" then
      -- Copy the escape and whatever it escapes as one unit, so `\ ` (an
      -- explicitly literal space) and `\_s` survive untouched.
      local nxt = pat:sub(i + 1, i + 1)
      if nxt == "{" then in_brace = true end
      out[#out + 1] = pat:sub(i, i + 1)
      i = i + 2
    elseif c == "}" and in_brace then
      -- A `\{n,m}` quantifier opens escaped and closes bare.
      in_brace = false
      out[#out + 1] = c
      i = i + 1
    elseif c == "[" and not in_class and not in_brace then
      in_class = true
      out[#out + 1] = c
      i = i + 1
    elseif c == "]" and in_class then
      in_class = false
      out[#out + 1] = c
      i = i + 1
    elseif c == " " and not in_class and not in_brace then
      -- Collapse a run of spaces: two spaces in the source may well be one
      -- space plus a wrap, so a single \_s\+ is the more useful reading.
      local j = i
      while pat:sub(j, j) == " " do j = j + 1 end
      out[#out + 1] = M.JOIN
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
