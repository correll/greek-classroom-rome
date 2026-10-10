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
      local out = { latex("\\begin{flowbox}{olive}{" .. esc(label) .. "}") }
      for _, b in ipairs(el.content) do out[#out+1] = b end
      out[#out+1] = latex("\\end{flowbox}")
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
      local out = { latex("\\begin{flowbox}{olive}{Answer key}") }
      for _, b in ipairs(el.content) do out[#out+1] = b end
      out[#out+1] = latex("\\end{flowbox}")
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

  -- the reading: Greek text with a running vocabulary beside it. The
  -- blocks before the nested `gloss` div are the passage; the gloss div is
  -- set in a narrow column to its right; anything after it (comprehension
  -- questions, answers) runs full width underneath.
  if cls == "reading" then
    local title  = el.attributes["title"]  or ""
    local source = el.attributes["source"] or ""
    local right  = title
    if source ~= "" then right = (title ~= "" and (title .. " · ") or "") .. source end
    local before, gloss, after = {}, nil, {}
    for _, b in ipairs(el.content) do
      if gloss == nil and b.t == "Div" and b.classes:includes("gloss") then
        gloss = b
      elseif gloss == nil then
        before[#before+1] = b
      else
        after[#after+1] = b
      end
    end
    if FORMAT:match("latex") then
      local out = { latex("\\lessonrubric{The Reading}{" .. escrich(right) .. "}") }
      out[#out+1] = latex("\\begin{readingcols}")
      for _, b in ipairs(before) do out[#out+1] = b end
      if gloss then
        out[#out+1] = latex("\\begin{readinggloss}")
        for _, b in ipairs(gloss.content) do out[#out+1] = b end
        out[#out+1] = latex("\\end{readinggloss}")
      end
      out[#out+1] = latex("\\end{readingcols}")
      for _, b in ipairs(after) do out[#out+1] = b end
      return out
    else
      local meta = right ~= "" and ('<span class="rubric-meta">'
            .. right:gsub("%*([^%*]+)%*", "<em>%1</em>") .. "</span>") or ""
      local out = { html('<section class="phase reading"><h4 class="rubric">The Reading'
            .. meta .. '</h4><div class="readingcols"><div class="greek">') }
      for _, b in ipairs(before) do out[#out+1] = b end
      out[#out+1] = html('</div><div class="gloss">')
      if gloss then for _, b in ipairs(gloss.content) do out[#out+1] = b end end
      out[#out+1] = html("</div></div>")
      for _, b in ipairs(after) do out[#out+1] = b end
      out[#out+1] = html("</section>")
      return out
    end
  end

  -- the glossaries at the back: two columns, letter headings that are not
  -- sections (they stay out of the contents), one compact line per entry
  if cls == "glossary" then
    if FORMAT:match("latex") then
      local out = { latex("\\begin{glossarycols}") }
      for _, b in ipairs(el.content) do
        if b.t == "Header" then
          out[#out+1] = latex("\\glossletter{" .. pandoc.utils.stringify(b.content) .. "}")
        else
          out[#out+1] = b
        end
      end
      out[#out+1] = latex("\\end{glossarycols}")
      return out
    else
      local out = { html('<section class="glossary">') }
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
  if el.classes:includes("lesson") then
    if FORMAT:match("latex") then
      local out = { pandoc.RawInline("latex", "\\glosslesson{") }
      for _, i in ipairs(el.content) do out[#out+1] = i end
      out[#out+1] = pandoc.RawInline("latex", "}")
      return out
    end
    return nil
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
  local toplevel = el.attr and el.attr.classes:includes("toplevel")
  local ncols = #el.colspecs
  -- measure every column: longest cell and average cell length
  local longest, colmax, colsum, colcnt, colword = 0, {}, {}, {}, {}
  for i = 1, ncols do colmax[i], colsum[i], colcnt[i], colword[i] = 0, 0, 0, 0 end
  local function measure(rows, count)
    for _, r in ipairs(rows) do
      for i, c in ipairs(r.cells) do
        local n = utf8.len(pandoc.utils.stringify(c.contents)) or 0
        if n > longest then longest = n end
        if i <= ncols then
          if n > colmax[i] then colmax[i] = n end
          for w in pandoc.utils.stringify(c.contents):gmatch("%S+") do
            local wl = utf8.len(w) or 0
            if wl > colword[i] then colword[i] = wl end
          end
          if count then colsum[i] = colsum[i] + n; colcnt[i] = colcnt[i] + 1 end
        end
      end
    end
  end
  if el.head then measure(el.head.rows, false) end
  for _, body in ipairs(el.bodies) do measure(body.body, true) end
  -- a table whose cells are all short (a paradigm, a contraction chart)
  -- sizes to its content; a table with prose in it fills the line, and its
  -- wrapping columns share the width by how much they hold
  local natural = longest <= 22
  local spec, wide = {}, false
  if natural then
    for _, cs in ipairs(el.colspecs) do
      local a = cs[1]
      spec[#spec+1] = (a == "AlignRight") and "r" or (a == "AlignCenter") and "c" or "l"
    end
  else
    local weights, total, nx = {}, 0, 0
    for i = 1, ncols do
      if colmax[i] > 18 then
        local avg = colcnt[i] > 0 and colsum[i] / colcnt[i] or colmax[i]
        weights[i] = math.max(avg, 8) ^ 0.75
        total = total + weights[i]; nx = nx + 1
      end
    end
    for i = 1, ncols do
      if weights[i] then
        local share = math.max(weights[i] / total, 0.6 / nx)
        weights[i] = share
      end
    end
    local s = 0
    for i = 1, ncols do if weights[i] then s = s + weights[i] end end
    for i = 1, ncols do
      if weights[i] then
        spec[#spec+1] = string.format(
          ">{\\raggedright\\arraybackslash\\hsize=%.3f\\hsize}X", nx * weights[i] / s)
      else
        spec[#spec+1] = "l"
      end
    end
    wide = true
  end
  local head = el.head and el.head.rows or {}
  local headhas = false
  for _, r in ipairs(head) do
    for _, c in ipairs(r.cells) do
      if #c.contents > 0 and pandoc.utils.stringify(c.contents) ~= "" then headhas = true end
    end
  end
  -- a tall prose table inside a box: the box can break only between
  -- paragraphs, so the table is set as a stack of two-row tabulars with
  -- identical column widths, and the box may break between any two of them
  if wide and (not toplevel) and nrows > 6 then
    local shares, rest, wsum = {}, 1, 0
    for i = 1, ncols do
      if colmax[i] <= 18 then
        local avg = colcnt[i] > 0 and colsum[i] / colcnt[i] or colmax[i]
        shares[i] = (math.min(colmax[i], avg * 1.3) + 2) / 68; rest = rest - shares[i]
      else
        local avg = colcnt[i] > 0 and colsum[i] / colcnt[i] or colmax[i]
        shares[i] = -(math.max(avg, 8) ^ 0.75); wsum = wsum - shares[i]
      end
    end
    local cs, tot = {}, 0
    for i = 1, ncols do
      if shares[i] < 0 then shares[i] = rest * (-shares[i]) / wsum end
      shares[i] = math.max(shares[i], (colword[i] + 3) / 62)
      tot = tot + shares[i]
    end
    for i = 1, ncols do
      shares[i] = shares[i] / tot
      cs[#cs+1] = string.format(">{\\raggedright\\arraybackslash\\hsize=%.3f\\hsize}X", ncols * shares[i])
    end
    local colspec = "@{}" .. table.concat(cs) .. "@{}"
    local body = {}
    for _, b in ipairs(el.bodies) do
      for _, l in ipairs(rows_tex(b.body, ncols)) do body[#body+1] = l end
    end
    local oddcol = headhas and "parch!60" or "white"
    local evencol = headhas and "white" or "parch!60"
    local out = { "\\par\\medskip" }
    local i = 1
    local first = true
    while i <= #body do
      local piece = {}
      if first then
        piece[#piece+1] = "\\noindent\\begin{tabularx}{\\linewidth}{" .. colspec .. "}"
        piece[#piece+1] = "\\toprule"
        if headhas then
          for _, l in ipairs(rows_tex(head, ncols)) do piece[#piece+1] = l end
          piece[#piece+1] = "\\midrule"
        end
      else
        piece[#piece+1] = "\\par\\penalty0\\nointerlineskip\\noindent{\\rowcolors{1}{" .. oddcol .. "}{" .. evencol .. "}\\begin{tabularx}{\\linewidth}{" .. colspec .. "}"
      end
      for k = i, math.min(i + 1, #body) do piece[#piece+1] = body[k] end
      i = i + 2
      if i > #body then piece[#piece+1] = "\\bottomrule" end
      piece[#piece+1] = first and "\\end{tabularx}" or "\\end{tabularx}}"
      out[#out+1] = table.concat(piece, "\n")
      first = false
    end
    out[#out+1] = "\\par\\medskip"
    return latex(table.concat(out, "\n"))
  end
  -- prose tables at the top level may run over a page: xltabular breaks,
  -- and repeats its header; inside a box a table must stay in one piece
  local env, open
  if wide and toplevel then
    env = "xltabular"
    open = "\\par\\medskip\\begingroup\\setlength{\\LTpre}{0pt}\\setlength{\\LTpost}{0pt}\\begin{xltabular}{\\linewidth}{@{}" .. table.concat(spec) .. "@{}}"
  elseif wide then
    env = "tabularx"
    open = "\\par\\medskip\\noindent\\begin{tabularx}{\\linewidth}{@{}" .. table.concat(spec) .. "@{}}"
  else
    env = "tabular"
    open = "\\par\\medskip\\noindent\\begin{adjustbox}{max width=\\linewidth}\\begin{tabular}{@{}" .. table.concat(spec) .. "@{}}"
  end
  local lines = { open, "\\toprule" }
  if headhas then
    for _, l in ipairs(rows_tex(head, ncols)) do lines[#lines+1] = l end
    lines[#lines+1] = "\\midrule"
  end
  if env == "xltabular" then lines[#lines+1] = "\\endhead" end
  for _, body in ipairs(el.bodies) do
    for _, l in ipairs(rows_tex(body.body, ncols)) do lines[#lines+1] = l end
  end
  lines[#lines+1] = "\\bottomrule"
  if env == "xltabular" then
    lines[#lines+1] = "\\end{xltabular}\\endgroup\\par\\medskip"
  else
    lines[#lines+1] = "\\end{" .. env .. "}" .. (env == "tabular" and "\\end{adjustbox}" or "") .. "\\par\\medskip"
  end
  return latex(table.concat(lines, "\n"))
end

-- first pass: mark the tables that stand outside any box
function Pandoc(doc)
  for _, b in ipairs(doc.blocks) do
    if b.t == "Table" then b.attr.classes:insert("toplevel") end
  end
  return doc
end

return {
  { Meta = Meta, Pandoc = Pandoc },
  { Div = Div, Span = Span, Table = Table },
}
