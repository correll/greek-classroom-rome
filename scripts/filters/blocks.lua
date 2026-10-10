--[[
  blocks.lua — maps the course's authoring blocks onto LaTeX
  environments and HTML sections.

  Authoring vocabulary (fenced divs in Markdown):

    ::: {.story time="5 min"}            the classroom scene
    ::: {.newgreek time="10 min"}        the new Greek
    ::: {.investigation time="15 min"}   the investigation
    ::: {.voice time="10 min" source="Homer, Iliad 1.1"}  the ancient voice
    ::: {.question time="5 min"}         the closing question
    ::: vocab                            vocabulary to memorise
    ::: {.exercise title="..."}          a numbered exercise
    ::: answers                          answer key (teacher edition only)
    ::: teacheronly                      teacher's notes (teacher edition only)
    ::: note                             an aside
    ::: paradigm                         a paradigm table
    ::: latinbridge                      "you already know this from Latin"

  Inline:
    [λόγος]{.gk}   Greek with display letterspacing
    [§4.2]{.gref}  cross-reference to the grammar volume
--]]

local edition = "student"

-- rubric label, LaTeX environment, HTML class
local PHASES = {
  story         = { "The Story",        "storybox",    "story"         },
  newgreek      = { "The New Greek",    "grammarbox",  "newgreek"      },
  investigation = { "The Investigation", nil,          "investigation" },
  voice         = { "The Ancient Voice", "voicebox",   "voice"         },
  question      = { "The Question",     "questionbox", "question"      },
}

local SIMPLE = {
  note        = { "notebox",    "note",        "Note"              },
  grammar     = { "grammarbox", "grammar",     nil                 },
  latinbridge = { "notebox",    "latinbridge", "From Latin"        },
  vocab       = { nil,          "vocab",       "Words to Learn"    },
  paradigm    = { nil,          "paradigm",    nil                 },
}

local function latex(s) return pandoc.RawBlock("latex", s) end
local function html(s)  return pandoc.RawBlock("html", s) end

local function esc(s)
  if not s then return "" end
  return (s:gsub("([&%%#_%${}])", "\\%1"))
end

-- Attribute values are plain text, but *asterisks* are honoured as italics
-- so that source lines can name a work: source="Homer, *Iliad* 1.1"
local function escrich(s)
  if not s then return "" end
  local out = esc(s)
  out = out:gsub("%*([^%*]+)%*", "\\textit{%1}")
  return out
end

function Meta(m)
  if m.edition then
    edition = pandoc.utils.stringify(m.edition)
  end
  return m
end

function Div(el)
  local cls = el.classes[1]
  if not cls then return nil end

  -- teacher-only material: character notes, staging, what to reveal when.
  -- Dropped from the student edition exactly as the answer keys are.
  if el.classes:includes("teacheronly") then
    if edition ~= "teacher" then return {} end
    local label = el.attributes["label"] or "For the teacher"
    if FORMAT:match("latex") then
      local out = { latex("\\begin{teacherbox}\\noindent{\\footnotesize\\scshape\\color{olive}"
            .. esc(label) .. "}\\par\\vspace{3pt}") }
      for _, b in ipairs(el.content) do out[#out+1] = b end
      out[#out+1] = latex("\\end{teacherbox}")
      return out
    else
      local out = { html('<section class="teacheronly"><h4 class="rubric">' .. label .. "</h4>") }
      for _, b in ipairs(el.content) do out[#out+1] = b end
      out[#out+1] = html("</section>")
      return out
    end
  end

  -- answer key: dropped unless building the teacher edition
  if el.classes:includes("answers") then
    if edition ~= "teacher" then return {} end
    if FORMAT:match("latex") then
      local out = { latex("\\begin{notebox}[colback=white,colframe=olive]\\noindent{\\footnotesize\\scshape\\color{olive}Answer key}\\par\\vspace{3pt}") }
      for _, b in ipairs(el.content) do out[#out+1] = b end
      out[#out+1] = latex("\\end{notebox}")
      return out
    else
      local out = { html('<section class="answers"><h4 class="rubric">Answer key</h4>') }
      for _, b in ipairs(el.content) do out[#out+1] = b end
      out[#out+1] = html("</section>")
      return out
    end
  end

  -- the five lesson phases
  local ph = PHASES[cls]
  if ph then
    local label, env, hcls = ph[1], ph[2], ph[3]
    local time   = el.attributes["time"]   or ""
    local source = el.attributes["source"] or ""
    local right  = source ~= "" and source or time

    if FORMAT:match("latex") then
      local out = { latex("\\lessonrubric{" .. esc(label) .. "}{" .. escrich(right) .. "}") }
      if env then out[#out+1] = latex("\\begin{" .. env .. "}") end
      for _, b in ipairs(el.content) do out[#out+1] = b end
      if env then out[#out+1] = latex("\\end{" .. env .. "}") end
      return out
    else
      local meta = right ~= "" and ('<span class="rubric-meta">'
            .. right:gsub("%*([^%*]+)%*", "<em>%1</em>") .. "</span>") or ""
      local out = { html('<section class="phase ' .. hcls .. '">'
            .. '<h4 class="rubric">' .. label .. meta .. "</h4>") }
      for _, b in ipairs(el.content) do out[#out+1] = b end
      out[#out+1] = html("</section>")
      return out
    end
  end

  -- simple boxes
  local sm = SIMPLE[cls]
  if sm then
    local env, hcls, label = sm[1], sm[2], sm[3]
    if FORMAT:match("latex") then
      local out = {}
      if env then out[#out+1] = latex("\\begin{" .. env .. "}") end
      if label then
        out[#out+1] = latex("\\noindent{\\footnotesize\\scshape\\color{terra}" .. esc(label) .. "}\\par\\vspace{3pt}")
      end
      if cls == "vocab" then out[#out+1] = latex("\\begin{vocablist}") end
      for _, b in ipairs(el.content) do out[#out+1] = b end
      if cls == "vocab" then out[#out+1] = latex("\\end{vocablist}") end
      if env then out[#out+1] = latex("\\end{" .. env .. "}") end
      return out
    else
      local out = { html('<section class="' .. hcls .. '">') }
      if label then out[#out+1] = html('<h4 class="rubric">' .. label .. "</h4>") end
      for _, b in ipairs(el.content) do out[#out+1] = b end
      out[#out+1] = html("</section>")
      return out
    end
  end

  -- exercises
  if cls == "exercise" then
    local title = el.attributes["title"] or ""
    if FORMAT:match("latex") then
      local out = { latex("\\exercisehead{" .. esc(title) .. "}") }
      for _, b in ipairs(el.content) do out[#out+1] = b end
      return out
    else
      local out = { html('<section class="exercise"><h4 class="rubric">Exercise'
            .. (title ~= "" and (" — " .. title) or "") .. "</h4>") }
      for _, b in ipairs(el.content) do out[#out+1] = b end
      out[#out+1] = html("</section>")
      return out
    end
  end

  -- part dividers
  if cls == "part" then
    local name = el.attributes["name"] or ""
    local goal = el.attributes["goal"] or ""
    if FORMAT:match("latex") then
      local out = { latex("\\coursepart{" .. esc(name) .. "}{" .. esc(goal) .. "}") }
      for _, b in ipairs(el.content) do out[#out+1] = b end
      return out
    else
      local out = { html('<section class="partdivider"><h2>' .. name .. "</h2>"
            .. (goal ~= "" and ('<p class="goal">' .. goal .. "</p>") or "")) }
      for _, b in ipairs(el.content) do out[#out+1] = b end
      out[#out+1] = html("</section>")
      return out
    end
  end

  return nil
end

function Span(el)
  if el.classes:includes("gk") and FORMAT:match("latex") then
    local out = { pandoc.RawInline("latex", "\\gk{") }
    for _, i in ipairs(el.content) do out[#out+1] = i end
    out[#out+1] = pandoc.RawInline("latex", "}")
    return out
  end
  if el.classes:includes("gap") then
    if FORMAT:match("latex") then
      return pandoc.RawInline("latex", "{\\gap}")
    else
      return pandoc.RawInline("html", '<span class="gap"></span>')
    end
  end
  if el.classes:includes("gref") and FORMAT:match("latex") then
    local txt = pandoc.utils.stringify(el.content):gsub("^§", "")
    return pandoc.RawInline("latex", "\\gref{" .. esc(txt) .. "}")
  end
  return nil
end

-- Tables. Pandoc writes every table as a longtable, and a longtable inside
-- a breakable tcolorbox cannot be split: the box breaks the page in front
-- of it and leaves the rest of the page empty. Every paradigm and gloss
-- table in the lessons fits on a page, so they are written as plain
-- tabulars instead; only the long lists at the back keep longtable.
local function cell_tex(cell)
  local s = pandoc.write(pandoc.Pandoc(cell.contents), "latex")
  return (s:gsub("^%s+", ""):gsub("%s+$", ""):gsub("\n\n", " "):gsub("\n", " "))
end

local function rows_tex(rows, ncols)
  local out = {}
  for _, row in ipairs(rows) do
    local cells = {}
    for i = 1, ncols do
      local c = row.cells[i]
      cells[#cells+1] = c and cell_tex(c) or ""
    end
    out[#out+1] = table.concat(cells, " & ") .. " \\\\"
  end
  return out
end

function Table(el)
  if not FORMAT:match("latex") then return nil end
  local nrows = 0
  for _, body in ipairs(el.bodies) do nrows = nrows + #body.body end
  if nrows > 30 then return nil end           -- a real list: leave longtable
  local ncols = #el.colspecs
  local spec = {}
  for i, cs in ipairs(el.colspecs) do
    local align, width = cs[1], cs[2]
    local a = (align == "AlignRight") and "r" or (align == "AlignCenter") and "c" or "l"
    if type(width) == "number" and width > 0 then
      local w = width * 0.96
      spec[#spec+1] = ">{\\raggedright\\arraybackslash}p{" .. string.format("%.3f", w) .. "\\linewidth}"
    else
      spec[#spec+1] = a
    end
  end
  local lines = { "\\par\\medskip\\noindent\\begin{tabular}{@{}" .. table.concat(spec) .. "@{}}", "\\toprule" }
  local head = el.head and el.head.rows or {}
  local headhas = false
  for _, r in ipairs(head) do
    for _, c in ipairs(r.cells) do
      if #c.contents > 0 and pandoc.utils.stringify(c.contents) ~= "" then headhas = true end
    end
  end
  if headhas then
    for _, l in ipairs(rows_tex(head, ncols)) do lines[#lines+1] = l end
    lines[#lines+1] = "\\midrule"
  end
  for _, body in ipairs(el.bodies) do
    for _, l in ipairs(rows_tex(body.body, ncols)) do lines[#lines+1] = l end
  end
  lines[#lines+1] = "\\bottomrule"
  lines[#lines+1] = "\\end{tabular}\\par\\medskip"
  return latex(table.concat(lines, "\n"))
end

return {
  { Meta = Meta },
  { Div = Div, Span = Span, Table = Table },
}
