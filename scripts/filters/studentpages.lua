--[[
  studentpages.lua — in the teacher's edition, print under each heading the
  page where the same material appears in the student's book.

  The map is produced by scripts/student_pages.py from the student edition's
  .aux file, so the student edition must be typeset first; the Makefile
  enforces that ordering. Headings that exist only in the teacher's edition
  (the character notes, the scope and sequence) are absent from the map and
  are left unannotated.

  Silent no-op for the student and grammar builds, and for HTML, where a
  printed page number means nothing.
--]]

local MAP      = "build/student-pages.lua"
local MAXLEVEL = 2   -- lessons and their sections; deeper headings would be noise

local edition = "student"
local pages   = nil

local function load_pages()
  local chunk = loadfile(MAP)
  if not chunk then return nil end          -- not built yet: annotate nothing
  local ok, tbl = pcall(chunk)
  if ok and type(tbl) == "table" then return tbl end
  return nil
end

function Meta(m)
  if m.edition then
    edition = pandoc.utils.stringify(m.edition)
  end
  if edition == "teacher" then
    pages = load_pages()
  end
  return m
end

function Header(el)
  if edition ~= "teacher" or pages == nil then return nil end
  if el.level > MAXLEVEL or el.identifier == "" then return nil end
  local p = pages[el.identifier]
  if not p then return nil end
  if FORMAT:match("latex") then
    return { el, pandoc.RawBlock("latex", "\\studentpage{" .. tostring(p) .. "}") }
  end
  return nil
end

return {
  { Meta = Meta },
  { Header = Header },
}
