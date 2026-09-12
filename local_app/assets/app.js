/* Awesome Systematic Trading — local app behavior (theme, search, copy).
   Plain JS, no dependencies, runs only from this local server. */
(function () {
  "use strict";

  // ---- theme toggle (persisted per browser via localStorage) ----
  var root = document.documentElement;
  var stored = null;
  try { stored = localStorage.getItem("asyst-theme"); } catch (e) { /* private mode */ }
  if (stored === "dark" || stored === "light") root.setAttribute("data-theme", stored);

  var toggle = document.getElementById("theme-toggle");
  if (toggle) {
    toggle.addEventListener("click", function () {
      var dark = root.getAttribute("data-theme") === "dark" ||
        (!root.getAttribute("data-theme") &&
          window.matchMedia("(prefers-color-scheme: dark)").matches);
      var next = dark ? "light" : "dark";
      root.setAttribute("data-theme", next);
      try { localStorage.setItem("asyst-theme", next); } catch (e) { /* ignore */ }
    });
  }

  // ---- hide badge images that cannot load (offline mode / no internet) ----
  Array.prototype.forEach.call(document.images, function (img) {
    var hide = function () { img.hidden = true; };
    if (img.complete && img.naturalWidth === 0 && img.src.indexOf(location.origin) !== 0) hide();
    else img.addEventListener("error", hide);
  });

  // ---- strategy search filter ----
  var search = document.getElementById("strategy-search");
  if (search) {
    var rows = Array.prototype.slice.call(document.querySelectorAll(".strategy-row"));
    var empty = document.getElementById("no-results");
    search.addEventListener("input", function () {
      var terms = search.value.toLowerCase().split(/\s+/).filter(Boolean);
      var visible = 0;
      rows.forEach(function (row) {
        var hay = row.getAttribute("data-search") || "";
        var show = terms.every(function (t) { return hay.indexOf(t) !== -1; });
        row.hidden = !show;
        if (show) visible++;
      });
      if (empty) empty.hidden = visible !== 0;
    });
  }

  // ---- copy code button ----
  var copyBtn = document.getElementById("copy-code");
  if (copyBtn) {
    copyBtn.addEventListener("click", function () {
      var parts = Array.prototype.map.call(
        document.querySelectorAll("pre.code .line .cd"),
        function (el) { return el.textContent; }
      );
      var done = function () {
        copyBtn.textContent = "Copied ✓";
        setTimeout(function () { copyBtn.textContent = "Copy code"; }, 1600);
      };
      var text = parts.join("\n");
      if (navigator.clipboard && navigator.clipboard.writeText) {
        navigator.clipboard.writeText(text).then(done, function () { fallbackCopy(text, done); });
      } else {
        fallbackCopy(text, done);
      }
    });
  }

  function fallbackCopy(text, done) {
    var ta = document.createElement("textarea");
    ta.value = text;
    ta.style.position = "fixed";
    ta.style.opacity = "0";
    document.body.appendChild(ta);
    ta.select();
    try { document.execCommand("copy"); done(); } catch (e) { /* ignore */ }
    document.body.removeChild(ta);
  }
})();
