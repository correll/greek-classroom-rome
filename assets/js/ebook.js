/* ------------------------------------------------------------------
   Flip-book reader for the course PDFs.

   Renders the real typeset pages with PDF.js, two to a spread, with a
   3D page turn. The sidebar's chapter list is read from each PDF's own
   bookmarks, so it can never drift from the book.

   window.GC_BOOKS is written into the page by scripts/build_site.py.
   ------------------------------------------------------------------ */
(function () {
  "use strict";

  var BOOKS = window.GC_BOOKS || [];
  var PAGE_RATIO = 0.7;          // 7in x 10in, replaced by the real page 1
  var CACHE_MAX = 30;
  var FLIP_MS = 620;

  if (!window.pdfjsLib) { fail("PDF.js did not load.",
      "The reader needs <code>vendor/pdfjs/pdf.min.js</code>."); return; }
  pdfjsLib.GlobalWorkerOptions.workerSrc = "vendor/pdfjs/pdf.worker.min.js";

  // ---- state ------------------------------------------------------
  var book = null, pdf = null, numPages = 0;
  var spread = 0, single = false, flipping = false;
  var outline = [], cache = new Map(), lastTargetW = 0;

  var $ = function (id) { return document.getElementById(id); };
  var stage = $("canvasarea"), bookEl = $("book");
  var slotL = $("slotL"), slotR = $("slotR");
  var btnPrev = $("prev"), btnNext = $("next");
  var slider = $("slider"), count = $("count"), chapLabel = $("chap");
  var tocEl = $("toc"), booksEl = $("books"), msg = $("msg");

  var reduceMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;

  // ---- small helpers ----------------------------------------------
  function store(k, v) {
    try { if (v === undefined) return localStorage.getItem(k);
          localStorage.setItem(k, v); } catch (e) { return null; }
  }
  function fail(title, body) {
    if (!msg) return;
    msg.hidden = false;
    msg.querySelector(".inner").innerHTML =
      "<h3>" + title + "</h3><p>" + body + "</p>";
  }
  function busy(on, label) {
    if (!msg) return;
    if (!on) { msg.hidden = true; return; }
    msg.hidden = false;
    msg.querySelector(".inner").innerHTML =
      '<div class="spinner"></div><p>' + (label || "Loading…") + "</p>";
  }

  // ---- spread model ------------------------------------------------
  // spread 0 shows page 1 alone on the right (a cover is a recto);
  // spread s > 0 shows pages 2s and 2s+1.
  function leftPage(s)  { return s === 0 ? 0 : 2 * s; }
  function rightPage(s) { return s === 0 ? 1 : 2 * s + 1; }
  function maxSpread()  { return single ? numPages : Math.floor(numPages / 2); }
  function spreadOf(p)  { return single ? p : (p <= 1 ? 0 : Math.floor(p / 2)); }
  function firstPage(s) { return single ? s : (leftPage(s) || rightPage(s)); }

  // ---- rendering ---------------------------------------------------
  function targetWidth() {
    var w = parseFloat(getComputedStyle(document.documentElement)
              .getPropertyValue("--page-w")) || 420;
    return Math.max(240, Math.round(w));
  }

  function renderPage(n) {
    if (!n || n < 1 || n > numPages) return Promise.resolve(null);
    if (cache.has(n)) {
      var hit = cache.get(n); cache.delete(n); cache.set(n, hit);
      return Promise.resolve(hit);
    }
    return pdf.getPage(n).then(function (page) {
      var dpr = Math.min(window.devicePixelRatio || 1, 2);
      var base = page.getViewport({ scale: 1 });
      var scale = (targetWidth() * dpr) / base.width;
      var vp = page.getViewport({ scale: scale });
      var cv = document.createElement("canvas");
      cv.width = Math.round(vp.width); cv.height = Math.round(vp.height);
      cv.setAttribute("role", "img");
      cv.setAttribute("aria-label", "Page " + n);
      var ctx = cv.getContext("2d", { alpha: false });
      ctx.fillStyle = "#fff"; ctx.fillRect(0, 0, cv.width, cv.height);
      return page.render({ canvasContext: ctx, viewport: vp }).promise.then(function () {
        cache.set(n, cv);
        while (cache.size > CACHE_MAX) cache.delete(cache.keys().next().value);
        return cv;
      });
    }).catch(function () { return null; });
  }

  function setSlot(slot, n) {
    return renderPage(n).then(function (cv) {
      slot.innerHTML = "";
      if (cv) { slot.appendChild(cv); slot.classList.remove("empty"); }
      else slot.classList.add("empty");
      return cv;
    });
  }

  function preload(s) {
    if (!("requestIdleCallback" in window)) return;
    requestIdleCallback(function () {
      [leftPage(s + 1), rightPage(s + 1), leftPage(s - 1), rightPage(s - 1)]
        .forEach(function (p) { if (p >= 1 && p <= numPages) renderPage(p); });
    }, { timeout: 1500 });
  }

  // ---- layout ------------------------------------------------------
  function layout() {
    if (!stage) return;
    var pad = window.innerWidth <= 832 ? 10 : 22;
    var availW = stage.clientWidth - pad * 2;
    var availH = stage.clientHeight - pad * 2;
    var cols = single ? 1 : 2;
    var h = availH;
    var w = h * PAGE_RATIO * cols;
    if (w > availW) { w = availW; h = (w / cols) / PAGE_RATIO; }
    var pw = Math.floor(w / cols), ph = Math.floor(h);
    document.documentElement.style.setProperty("--page-w", pw + "px");
    document.documentElement.style.setProperty("--page-h", ph + "px");
    // re-render if the page is now a lot bigger than what we cached
    if (lastTargetW && pw > lastTargetW * 1.3) { cache.clear(); draw(); }
    lastTargetW = pw;
  }

  // ---- drawing a spread --------------------------------------------
  function draw() {
    if (!pdf) return Promise.resolve();
    bookEl.classList.toggle("cover", !single && spread === 0);
    var l = single ? 0 : leftPage(spread);
    var r = single ? spread : rightPage(spread);
    return Promise.all([setSlot(slotL, l), setSlot(slotR, r)]).then(status);
  }

  function status() {
    var l = single ? spread : leftPage(spread);
    var r = single ? spread : rightPage(spread);
    var shown = (!single && l && r <= numPages) ? l + "–" + r
              : String(Math.min(r || l, numPages));
    count.textContent = shown + " of " + numPages;
    slider.max = String(numPages);
    slider.value = String(Math.min(Math.max(firstPage(spread), 1), numPages));
    btnPrev.disabled = spread <= (single ? 1 : 0);
    btnNext.disabled = spread >= maxSpread();
    markChapter();
    var id = book ? book.id : "";
    var p = firstPage(spread) || 1;
    history.replaceState(null, "", "#/" + id + "/" + p);
    store("gc-ebook", id + ":" + p);
  }

  function markChapter() {
    // a reader takes their bearings from the recto, so the heading that
    // governs the right-hand page is the one to show
    var p = single ? spread
          : (rightPage(spread) <= numPages ? rightPage(spread) : leftPage(spread));
    p = Math.max(p, 1);
    // The textbook nests lessons inside parts, the grammar nests sections
    // inside chapters, so a single depth is never the right answer. Show a
    // breadcrumb of the top two levels instead.
    var best = null, lvl0 = null, lvl1 = null;
    outline.forEach(function (o) {
      if (!o.page || o.page > p) return;
      if (!best || o.page >= best.page) best = o;
      if (o.depth === 0 && (!lvl0 || o.page >= lvl0.page)) lvl0 = o;
      if (o.depth === 1 && (!lvl1 || o.page >= lvl1.page)) lvl1 = o;
    });
    var current = null;
    Array.prototype.forEach.call(tocEl.querySelectorAll("a"), function (a) {
      var on = best && a.dataset.page === String(best.page) &&
               a.dataset.title === best.title;
      if (on) { a.setAttribute("aria-current", "true"); current = a; }
      else a.removeAttribute("aria-current");
    });
    if (current && current.scrollIntoView) {
      current.scrollIntoView({ block: "nearest" });
    }
    var crumbs = [];
    if (lvl0) crumbs.push(lvl0.title);
    if (lvl1 && (!lvl0 || lvl1.page >= lvl0.page)) crumbs.push(lvl1.title);
    chapLabel.textContent = crumbs.length ? crumbs.join(" \u00b7 ")
                          : (best ? best.title : "");
  }

  // ---- the page turn -----------------------------------------------
  function flip(dir) {
    if (flipping || !pdf) return;
    var target = spread + dir;
    if (target < (single ? 1 : 0) || target > maxSpread()) return;
    if (single || reduceMotion) { spread = target; draw().then(function(){preload(spread);}); return; }

    flipping = true;
    var fwd = dir > 0;
    var frontN = fwd ? rightPage(spread) : leftPage(spread);
    var backN  = fwd ? leftPage(target)  : rightPage(target);

    Promise.all([renderPage(frontN), renderPage(backN)]).then(function (pair) {
      var frontCv = pair[0], backCv = pair[1];
      if (!frontCv && !backCv) { flipping = false; spread = target; return draw(); }

      var leaf = document.createElement("div");
      leaf.className = "leaf " + (fwd ? "fwd" : "back");
      var f1 = document.createElement("div"); f1.className = "face front";
      var f2 = document.createElement("div"); f2.className = "face back";
      if (frontCv) f1.appendChild(frontCv);
      if (backCv) f2.appendChild(backCv);
      var shade = document.createElement("div"); shade.className = "shade";
      leaf.appendChild(f1); leaf.appendChild(f2); leaf.appendChild(shade);
      bookEl.appendChild(leaf);

      // reveal what sits under the leaf as it lifts
      var under = fwd ? setSlot(slotR, rightPage(target))
                      : setSlot(slotL, leftPage(target));

      var from = fwd ? "rotateY(0deg)"    : "rotateY(0deg)";
      var to   = fwd ? "rotateY(-180deg)" : "rotateY(180deg)";
      var a = leaf.animate([{ transform: from }, { transform: to }],
        { duration: FLIP_MS, easing: "cubic-bezier(.32,.03,.28,1)", fill: "forwards" });
      shade.animate([{ opacity: 0 }, { opacity: 0.8, offset: 0.52 }, { opacity: 0 }],
        { duration: FLIP_MS, fill: "forwards" });

      var done = a.finished || new Promise(function (res) { a.onfinish = res; });
      Promise.all([done, under]).then(function () {
        spread = target;
        bookEl.classList.toggle("cover", spread === 0);
        var settle = fwd ? setSlot(slotL, leftPage(spread))
                         : setSlot(slotR, rightPage(spread));
        return settle;
      }).then(function () {
        if (leaf.parentNode) leaf.parentNode.removeChild(leaf);
        flipping = false;
        status();
        preload(spread);
      });
    });
  }

  function goToPage(p, animate) {
    p = Math.min(Math.max(1, p | 0), numPages);
    var s = spreadOf(p);
    if (s === spread) return;
    if (animate && Math.abs(s - spread) === 1) { flip(s - spread); return; }
    spread = s;
    draw().then(function () { preload(spread); });
  }

  // ---- outline -----------------------------------------------------
  function destPage(dest) {
    var d = dest;
    var resolve = typeof d === "string" ? pdf.getDestination(d) : Promise.resolve(d);
    return resolve.then(function (arr) {
      if (!Array.isArray(arr) || !arr.length) return null;
      var ref = arr[0];
      if (ref && typeof ref === "object") return pdf.getPageIndex(ref).then(function (i) { return i + 1; });
      if (typeof ref === "number") return ref + 1;
      return null;
    }).catch(function () { return null; });
  }

  function loadOutline() {
    return pdf.getOutline().then(function (raw) {
      var flat = [];
      function walk(items, depth) {
        return (items || []).reduce(function (chain, it) {
          return chain.then(function () {
            return destPage(it.dest).then(function (p) {
              flat.push({ title: (it.title || "").trim(), page: p, depth: depth });
              if (it.items && it.items.length && depth < 2) return walk(it.items, depth + 1);
            });
          });
        }, Promise.resolve());
      }
      return walk(raw, 0).then(function () {
        if (flat.filter(function (f) { return f.depth > 0; }).length > 240)
          flat = flat.filter(function (f) { return f.depth === 0; });
        return flat;
      });
    }).catch(function () { return []; });
  }

  function paintToc() {
    if (!outline.length) {
      tocEl.innerHTML = '<p class="r-links">This volume has no bookmarks.</p>';
      return;
    }
    var ol = document.createElement("ol");
    outline.forEach(function (o) {
      var li = document.createElement("li");
      li.className = "depth-" + o.depth;
      var a = document.createElement("a");
      a.href = "#/" + book.id + "/" + (o.page || 1);
      a.dataset.page = String(o.page || "");
      a.dataset.title = o.title;
      a.innerHTML = '<span class="t-label"></span><span class="t-page"></span>';
      a.firstChild.textContent = o.title;
      a.lastChild.textContent = o.page || "";
      a.addEventListener("click", function (ev) {
        ev.preventDefault();
        closeDrawer();
        goToPage(o.page || 1, true);
      });
      li.appendChild(a); ol.appendChild(li);
    });
    tocEl.innerHTML = ""; tocEl.appendChild(ol);
  }

  // ---- books -------------------------------------------------------
  function paintBooks() {
    booksEl.innerHTML = "";
    BOOKS.forEach(function (b) {
      var btn = document.createElement("button");
      btn.type = "button";
      btn.innerHTML = '<span class="bk-t"></span><span class="bk-s"></span>';
      btn.firstChild.textContent = b.title;
      btn.lastChild.textContent = b.subtitle;
      if (book && b.id === book.id) btn.setAttribute("aria-current", "true");
      btn.addEventListener("click", function () { openBook(b, 1); });
      booksEl.appendChild(btn);
    });
  }

  function openBook(b, page) {
    if (book && b.id === book.id && pdf) { goToPage(page || 1, false); return; }
    book = b; pdf = null; cache.clear(); outline = [];
    paintBooks();
    tocEl.innerHTML = "";
    $("booktitle").innerHTML = "<b></b> · <span></span>";
    $("booktitle").firstChild.textContent = b.title;
    $("booktitle").lastChild.textContent = b.subtitle;
    busy(true, "Opening " + b.title + "…");

    pdfjsLib.getDocument({ url: b.file, cMapPacked: true }).promise.then(function (doc) {
      pdf = doc; numPages = doc.numPages;
      return doc.getPage(1).then(function (p1) {
        var vp = p1.getViewport({ scale: 1 });
        PAGE_RATIO = vp.width / vp.height;
        layout();
        return loadOutline();
      });
    }).then(function (ol) {
      outline = ol; paintToc();
      spread = spreadOf(Math.min(Math.max(1, page || 1), numPages));
      busy(false);
      return draw();
    }).then(function () { preload(spread); })
      .catch(function () {
        fail("That volume isn't built yet.",
          "The reader could not load <code>" + b.file + "</code>. " +
          "Run <code>make pdf teacher grammar</code>, then <code>make site</code>.");
      });
  }

  // ---- drawer ------------------------------------------------------
  function openDrawer() { document.body.classList.add("drawer-open"); }
  function closeDrawer() { document.body.classList.remove("drawer-open"); }

  // ---- wiring ------------------------------------------------------
  btnPrev.addEventListener("click", function () { flip(-1); });
  btnNext.addEventListener("click", function () { flip(1); });
  slider.addEventListener("input", function () { goToPage(+slider.value, false); });

  document.addEventListener("keydown", function (e) {
    if (e.target.matches("input, textarea")) return;
    if (e.key === "ArrowRight" || e.key === "PageDown") { flip(1); e.preventDefault(); }
    else if (e.key === "ArrowLeft" || e.key === "PageUp") { flip(-1); e.preventDefault(); }
    else if (e.key === "Home") { goToPage(1, false); }
    else if (e.key === "End") { goToPage(numPages, false); }
    else if (e.key === "Escape") { closeDrawer(); }
  });

  var tx = 0, ty = 0;
  stage.addEventListener("touchstart", function (e) {
    tx = e.changedTouches[0].clientX; ty = e.changedTouches[0].clientY;
  }, { passive: true });
  stage.addEventListener("touchend", function (e) {
    var dx = e.changedTouches[0].clientX - tx;
    var dy = e.changedTouches[0].clientY - ty;
    if (Math.abs(dx) > 48 && Math.abs(dx) > Math.abs(dy) * 1.6) flip(dx < 0 ? 1 : -1);
  }, { passive: true });

  $("menu").addEventListener("click", openDrawer);
  $("scrim").addEventListener("click", closeDrawer);

  $("spreadtoggle").addEventListener("click", function () {
    var keep = firstPage(spread) || 1;      // read the page in the OLD mode
    single = !single;
    this.setAttribute("aria-pressed", String(single));
    this.textContent = single ? "Single page" : "Two pages";
    document.body.classList.toggle("single", single);
    spread = spreadOf(Math.min(Math.max(keep, 1), numPages));
    cache.clear(); layout(); draw();
  });

  $("theme").addEventListener("click", function () {
    var root = document.documentElement;
    var next = root.getAttribute("data-theme") === "dark" ? "light" : "dark";
    root.setAttribute("data-theme", next);
    store("gc-theme", next);
  });

  $("full").addEventListener("click", function () {
    if (document.fullscreenElement) document.exitFullscreen();
    else document.documentElement.requestFullscreen().catch(function () {});
  });

  var rt;
  window.addEventListener("resize", function () {
    clearTimeout(rt); rt = setTimeout(function () { autoSingle(); layout(); }, 120);
  });

  function autoSingle() {
    var narrow = window.innerWidth < 760;
    if (narrow && !single) {
      single = true; document.body.classList.add("single");
      $("spreadtoggle").setAttribute("aria-pressed", "true");
      $("spreadtoggle").textContent = "Single page";
      spread = Math.max(1, firstPage(spread) || 1);
    }
  }

  window.addEventListener("hashchange", function () {
    var h = parseHash();
    if (!h) return;
    var b = BOOKS.filter(function (x) { return x.id === h.id; })[0];
    if (b && (!book || b.id !== book.id)) openBook(b, h.page);
    else goToPage(h.page, false);
  });

  function parseHash() {
    var m = /^#\/([\w-]+)\/(\d+)/.exec(location.hash || "");
    return m ? { id: m[1], page: +m[2] } : null;
  }

  // ---- start -------------------------------------------------------
  try {
    var t = store("gc-theme");
    if (t) document.documentElement.setAttribute("data-theme", t);
  } catch (e) {}

  if (!BOOKS.length) {
    fail("No volumes found.", "Run <code>make pdf teacher grammar</code> and rebuild the site.");
    return;
  }

  autoSingle();
  layout();
  paintBooks();

  var start = parseHash();
  if (!start) {
    var saved = (store("gc-ebook") || "").split(":");
    if (saved.length === 2) start = { id: saved[0], page: +saved[1] || 1 };
  }
  var chosen = start && BOOKS.filter(function (b) { return b.id === start.id; })[0];
  openBook(chosen || BOOKS[0], chosen ? start.page : 1);
})();
