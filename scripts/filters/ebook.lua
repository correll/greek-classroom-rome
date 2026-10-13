--[[
ebook.lua - the few things an EPUB needs that the print and web builds do not.
Runs before blocks.lua.

  * A part divider becomes a real chapter heading ("Part I · The Strange
    Language") with its goal under it, so that the parts appear in the
    Kindle's table of contents and each starts a new page.
  * Lessons are numbered as in the print book: every level-1 heading that
    is not {.unnumbered} gets its number in front ("1  The Unwelcome Tablet").
]]

local ROMAN = { "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X" }
local part, lesson = 0, 0

local function walk_blocks(blocks)
  local out = {}
  for _, b in ipairs(blocks) do
    if b.t == "Div" and b.classes:includes("part") then
      part = part + 1
      local name = b.attributes["name"] or ""
      local goal = b.attributes["goal"] or ""
      local title = "Part " .. (ROMAN[part] or tostring(part)) .. " · " .. name
      out[#out+1] = pandoc.Header(1, pandoc.Inlines(title),
                      pandoc.Attr("part-" .. part, { "unnumbered", "partdivider" }))
      if goal ~= "" then
        out[#out+1] = pandoc.Div(pandoc.Para(pandoc.Emph(pandoc.Inlines(goal))),
                        pandoc.Attr("", { "partgoal" }))
      end
      for _, c in ipairs(b.content) do out[#out+1] = c end
    elseif b.t == "Header" and b.level == 1 and not b.classes:includes("unnumbered") then
      lesson = lesson + 1
      local inl = pandoc.Inlines({ pandoc.Span(pandoc.Inlines(tostring(lesson)),
                                     pandoc.Attr("", { "num" })), pandoc.Space() })
      inl:extend(b.content)
      b.content = inl
      b.classes:insert("unnumbered")
      out[#out+1] = b
    else
      out[#out+1] = b
    end
  end
  return out
end

function Pandoc(doc)
  doc.blocks = walk_blocks(doc.blocks)
  return doc
end
