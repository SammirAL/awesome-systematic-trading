#!/usr/bin/env python3
"""
Awesome Systematic Trading — local, one-click, zero-dependency web app.

Serves the curated list (README.md / README_zh.md) and a searchable explorer
for the 60+ strategy implementations in static/strategies/, entirely from the
Python 3 standard library.

Security posture (defense in depth, even though all content is repo-owned):
  * Binds to 127.0.0.1 by default — never exposed to the network.
  * GET/HEAD only; strict path allowlist; path-traversal guards on every route.
  * All file content is HTML-escaped before rendering; no eval/exec anywhere.
  * Hardened response headers (CSP, nosniff, frame denial, no referrer).
  * No third-party packages, no CDN, no telemetry. External requests are
    limited to the badge images embedded in the README, and even those can be
    disabled with --offline.

Runs on Python 3.8+.
"""

import argparse
import html
import io
import keyword
import os
import re
import socket
import sys
import threading
import tokenize
import webbrowser
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import quote, unquote, urlsplit

APP_NAME = "Awesome Systematic Trading"
REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSETS_DIR = os.path.join(REPO_ROOT, "local_app", "assets")
IMAGES_DIR = os.path.join(REPO_ROOT, "static", "images")
STRATEGIES_DIR = os.path.join(REPO_ROOT, "static", "strategies")

DEFAULT_PORT = 8420
IMAGE_TYPES = {
    ".jpeg": "image/jpeg",
    ".jpg": "image/jpeg",
    ".png": "image/png",
    ".gif": "image/gif",
    ".svg": "image/svg+xml",
    ".webp": "image/webp",
    ".ico": "image/x-icon",
}
ASSET_TYPES = {".css": "text/css; charset=utf-8", ".js": "text/javascript; charset=utf-8"}

# Markdown documents served as rendered pages: route -> (file, page title, lang)
MD_PAGES = {
    "/": ("README.md", "Home", "en"),
    "/zh": ("README_zh.md", "中文", "zh"),
    "/run-locally": ("RUN_LOCALLY.md", "Run locally", "en"),
}
# Rewrites applied to relative markdown links so navigation stays inside the app.
MD_LINK_REWRITES = {
    "README.md": "/",
    "README_zh.md": "/zh",
    "RUN_LOCALLY.md": "/run-locally",
}

OFFLINE = False  # set by --offline: CSP then blocks the external badge images


# --------------------------------------------------------------------------
# Minimal GitHub-flavored-markdown renderer (the subset used by this repo:
# headings, tables, nested lists, blockquotes, raw HTML blocks, inline
# links/images/bold/italic/code). Everything is escaped before markup is added.
# --------------------------------------------------------------------------

_COMMENT_RE = re.compile(r"^\s*<!--.*?-->\s*$")
_RAW_HTML_RE = re.compile(r"^\s*</?\w+")
_HEADING_RE = re.compile(r"^(#{1,6})\s+(.*?)\s*#*\s*$")
_LIST_RE = re.compile(r"^(\s*)-\s+(.*)$")
_TABLE_SEP_RE = re.compile(r"^\s*\|?\s*:?-{2,}:?\s*(\|\s*:?-{2,}:?\s*)*\|?\s*$")
_CODE_SPAN_RE = re.compile(r"`([^`]+)`")
_IMAGE_RE = re.compile(r"!\[([^\]]*)\]\(([^)\s]+?)\)")
_LINK_RE = re.compile(r"\[([^\]]+)\]\(([^)\s]+?)\)")
_BOLD_RE = re.compile(r"\*\*(.+?)\*\*")
_ITALIC_RE = re.compile(r"(?<!\*)\*([^*]+)\*(?!\*)")
_SLUG_STRIP_RE = re.compile(r"[^\w\- ]", re.UNICODE)


def github_slug(text, used):
    """GitHub-compatible heading anchor (also matches CJK headings)."""
    text = _LINK_RE.sub(r"\1", text)  # slug is computed on the link text
    slug = _SLUG_STRIP_RE.sub("", text.strip().lower()).replace(" ", "-")
    n = used.get(slug, 0)
    used[slug] = n + 1
    return slug if n == 0 else "%s-%d" % (slug, n)


def _rewrite_url(url):
    """Keep navigation local and drop anything that is not http(s)/relative."""
    if url.startswith("#"):
        return url
    if url.startswith(("http://", "https://")):
        return url
    clean = url[2:] if url.startswith("./") else url.lstrip("/")
    if clean in MD_LINK_REWRITES:
        return MD_LINK_REWRITES[clean]
    if clean.startswith("static/strategies/"):
        return "/strategy/" + quote(clean[len("static/strategies/"):])
    if clean.startswith("static/"):
        return "/" + clean
    if re.match(r"^[a-zA-Z][a-zA-Z0-9+.-]*:", url):  # javascript:, data:, ...
        return "#"
    return "/" + clean


def render_inline(text):
    """Escape, then apply the inline markdown rules used in this repo."""
    text = html.escape(text, quote=True)

    codes = []

    def stash_code(m):
        codes.append("<code>%s</code>" % m.group(1))
        return "\x00%d\x00" % (len(codes) - 1)

    text = _CODE_SPAN_RE.sub(stash_code, text)
    text = _IMAGE_RE.sub(
        lambda m: '<img alt="%s" src="%s" loading="lazy">'
        % (m.group(1), _rewrite_url(m.group(2))),
        text,
    )

    def make_link(m):
        href = _rewrite_url(m.group(2))
        extra = ' target="_blank" rel="noopener noreferrer"' if href.startswith("http") else ""
        return '<a href="%s"%s>%s</a>' % (href, extra, m.group(1))

    text = _LINK_RE.sub(make_link, text)
    text = _BOLD_RE.sub(r"<strong>\1</strong>", text)
    text = _ITALIC_RE.sub(r"<em>\1</em>", text)
    return re.sub(r"\x00(\d+)\x00", lambda m: codes[int(m.group(1))], text)


def _rewrite_raw_html(line):
    """Pass repo-authored HTML through, pointing local srcs at our routes."""
    return re.sub(r'src="(\./)?(static/[^"]+)"', lambda m: 'src="/%s"' % m.group(2), line)


def render_markdown(md_text, used_slugs=None):
    used = used_slugs if used_slugs is not None else {}
    lines = md_text.splitlines()
    out = []
    i = 0
    while i < len(lines):
        line = lines[i]
        stripped = line.strip()

        if not stripped or _COMMENT_RE.match(line):
            i += 1
            continue

        if _RAW_HTML_RE.match(line):
            out.append(_rewrite_raw_html(line))
            i += 1
            continue

        m = _HEADING_RE.match(line)
        if m:
            level, content = len(m.group(1)), m.group(2)
            slug = github_slug(content, used)
            out.append(
                '<h%d id="%s"><a class="anchor" href="#%s" aria-hidden="true">#</a>%s</h%d>'
                % (level, html.escape(slug, quote=True), quote(slug), render_inline(content), level)
            )
            i += 1
            continue

        if line.lstrip().startswith(">"):
            quoted = []
            while i < len(lines) and lines[i].lstrip().startswith(">"):
                quoted.append(re.sub(r"^\s*>\s?", "", lines[i]))
                i += 1
            out.append("<blockquote>%s</blockquote>" % render_markdown("\n".join(quoted), used))
            continue

        if "|" in stripped and i + 1 < len(lines) and _TABLE_SEP_RE.match(lines[i + 1]):
            header = [c.strip() for c in stripped.strip("|").split("|")]
            i += 2
            rows = []
            while i < len(lines) and "|" in lines[i] and lines[i].strip():
                rows.append([c.strip() for c in lines[i].strip().strip("|").split("|")])
                i += 1
            table = ["<div class='table-wrap'><table><thead><tr>"]
            table += ["<th>%s</th>" % render_inline(c) for c in header]
            table.append("</tr></thead><tbody>")
            for row in rows:
                table.append("<tr>" + "".join("<td>%s</td>" % render_inline(c) for c in row) + "</tr>")
            table.append("</tbody></table></div>")
            out.append("".join(table))
            continue

        m = _LIST_RE.match(line)
        if m:
            items = []  # (depth, text)
            while i < len(lines):
                lm = _LIST_RE.match(lines[i])
                if not lm:
                    break
                items.append((len(lm.group(1)) // 2, lm.group(2)))
                i += 1
            depth = -1
            parts = []
            for d, text in items:
                while depth < d:
                    parts.append("<ul>")
                    depth += 1
                while depth > d:
                    parts.append("</ul>")
                    depth -= 1
                parts.append("<li>%s</li>" % render_inline(text))
            while depth >= 0:
                parts.append("</ul>")
                depth -= 1
            out.append("".join(parts))
            continue

        out.append("<p>%s</p>" % render_inline(stripped))
        i += 1

    return "\n".join(out)


# --------------------------------------------------------------------------
# Strategy catalog: filesystem scan enriched with the metadata already present
# in the README strategy tables (Sharpe, volatility, rebalancing, paper link).
# --------------------------------------------------------------------------

_README_STRATEGY_ROW = re.compile(
    r"\|\s*(?P<title>[^|]+?)\s*\|\s*`(?P<sharpe>[^`]*)`\s*\|\s*`(?P<vol>[^`]*)`\s*\|\s*"
    r"`(?P<rebalancing>[^`]*)`\s*\|\s*\[QuantConnect\]\(\./static/strategies/(?P<file>[^)]+)\)"
    r"\s*\|\s*\[Paper\]\((?P<paper>[^)\s]+)\)"
)
_SOURCE_URL_RE = re.compile(r"^#\s*(https?://\S+)\s*$")


def load_strategies():
    """Return a sorted list of strategy dicts. Never trusts names outside the dir."""
    readme_meta = {}
    try:
        with open(os.path.join(REPO_ROOT, "README.md"), encoding="utf-8") as f:
            for m in _README_STRATEGY_ROW.finditer(f.read()):
                readme_meta.setdefault(m.group("file"), m.groupdict())
    except OSError:
        pass

    strategies = []
    for name in sorted(os.listdir(STRATEGIES_DIR)):
        path = os.path.join(STRATEGIES_DIR, name)
        if not os.path.isfile(path) or name.startswith("."):
            continue
        source_url, desc_lines = "", []
        try:
            with open(path, encoding="utf-8", errors="replace") as f:
                head = [f.readline() for _ in range(200)]
            for idx, line in enumerate(head):
                m = _SOURCE_URL_RE.match(line.strip())
                if m:
                    source_url = m.group(1)
                    for later in head[idx + 1:]:
                        later = later.strip()
                        if later.startswith("#"):
                            text = later.lstrip("#").strip()
                            if text:
                                desc_lines.append(text)
                            elif desc_lines:
                                break
                        else:
                            break
                    break
        except OSError:
            continue
        meta = readme_meta.get(name, {})
        display = name[:-3] if name.endswith(".py") else name
        strategies.append(
            {
                "file": name,
                "title": meta.get("title") or display.replace("-", " ").title(),
                "sharpe": meta.get("sharpe", ""),
                "vol": meta.get("vol", ""),
                "rebalancing": meta.get("rebalancing", ""),
                "paper": meta.get("paper") or source_url,
                "description": " ".join(desc_lines)[:280],
                "size": os.path.getsize(path),
            }
        )
    return strategies


# --------------------------------------------------------------------------
# Python syntax highlighting with the stdlib tokenizer (safe fallback: plain).
# --------------------------------------------------------------------------


def highlight_python(source):
    """Return escaped HTML with token spans; spans never cross line breaks."""
    classes = []  # (abs_start, abs_end, css_class)
    line_offsets = [0]
    for line in source.splitlines(keepends=True):
        line_offsets.append(line_offsets[-1] + len(line))

    def abs_pos(row, col):
        return line_offsets[row - 1] + col

    try:
        tokens = list(tokenize.generate_tokens(io.StringIO(source).readline))
        for tok in tokens:
            css = None
            if tok.type == tokenize.COMMENT:
                css = "c"
            elif tok.type == tokenize.STRING:
                css = "s"
            elif tok.type == tokenize.NUMBER:
                css = "n"
            elif tok.type == tokenize.NAME and keyword.iskeyword(tok.string):
                css = "k"
            elif tok.type == tokenize.NAME and tok.string in ("self", "cls"):
                css = "b"
            if css:
                classes.append((abs_pos(*tok.start), abs_pos(*tok.end), css))
    except (tokenize.TokenError, SyntaxError, IndentationError, ValueError):
        classes = []

    parts = []
    cursor = 0
    for start, end, css in classes:
        if start < cursor:
            continue
        parts.append(html.escape(source[cursor:start], quote=True))
        chunk = html.escape(source[start:end], quote=True)
        chunk = chunk.replace("\n", '</span>\n<span class="tok-%s">' % css)
        parts.append('<span class="tok-%s">%s</span>' % (css, chunk))
        cursor = end
    parts.append(html.escape(source[cursor:], quote=True))
    return "".join(parts)


def render_code_page(name, source):
    highlighted = highlight_python(source)
    lines = highlighted.split("\n")
    body = []
    for num, content in enumerate(lines, 1):
        body.append(
            '<span class="line" id="L%d"><a class="no" href="#L%d">%d</a>'
            '<span class="cd">%s</span></span>' % (num, num, num, content or "")
        )
    # .line spans are display:block — join without "\n" so the pre does not
    # render an extra blank line between them.
    return '<pre class="code" tabindex="0">%s</pre>' % "".join(body)


# --------------------------------------------------------------------------
# Page chrome
# --------------------------------------------------------------------------


def page(title, body, active="", strategy_count=0):
    nav = [
        ("/", "List", "home"),
        ("/zh", "中文", "zh"),
        ("/strategies", "Strategies (%d)" % strategy_count, "strategies"),
        ("/run-locally", "About this app", "about"),
    ]
    links = "".join(
        '<a href="%s"%s>%s</a>'
        % (href, ' class="active"' if key == active else "", label)
        for href, label, key in nav
    )
    return """<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="referrer" content="no-referrer">
<title>%s · %s</title>
<link rel="icon" href="/static/images/awesome-systematic-trading.jpeg">
<link rel="stylesheet" href="/assets/style.css">
</head>
<body>
<header class="topbar">
  <a class="brand" href="/">📈 %s</a>
  <nav>%s</nav>
  <button id="theme-toggle" type="button" title="Toggle dark mode" aria-label="Toggle dark mode">🌓</button>
</header>
<main>
%s
</main>
<footer>
  <p>Served locally from your machine · no telemetry, no tracking · GET/HEAD only, bound to localhost.</p>
</footer>
<script src="/assets/app.js"></script>
</body>
</html>""" % (html.escape(title), APP_NAME, APP_NAME, links, body)


def strategies_page(strategies):
    rows = []
    for s in strategies:
        paper = (
            '<a href="%s" target="_blank" rel="noopener noreferrer">Paper</a>'
            % html.escape(s["paper"], quote=True)
            if s["paper"].startswith(("http://", "https://"))
            else ""
        )
        rows.append(
            '<tr class="strategy-row" data-search="%s">'
            '<td><a href="/strategy/%s">%s</a><div class="desc">%s</div></td>'
            "<td>%s</td><td>%s</td><td>%s</td><td>%s</td></tr>"
            % (
                html.escape((s["title"] + " " + s["file"] + " " + s["description"]).lower(), quote=True),
                quote(s["file"]),
                html.escape(s["title"]),
                html.escape(s["description"]),
                html.escape(s["sharpe"]) or "—",
                html.escape(s["vol"]) or "—",
                html.escape(s["rebalancing"]) or "—",
                paper,
            )
        )
    body = """
<h1>Strategy implementations</h1>
<p>%d QuantConnect (LEAN) algorithms from this repository, with the Sharpe ratio,
volatility and rebalancing data of the curated list. Click a title to read the
code with syntax highlighting — or download it to run it in
<a href="https://github.com/QuantConnect/Lean" target="_blank" rel="noopener noreferrer">LEAN</a>.</p>
<input id="strategy-search" type="search" placeholder="Filter strategies… (e.g. momentum, crypto, reversal)" autocomplete="off" autofocus>
<div class="table-wrap"><table id="strategy-table">
<thead><tr><th>Strategy</th><th>Sharpe</th><th>Volatility</th><th>Rebalancing</th><th>Source</th></tr></thead>
<tbody>%s</tbody>
</table></div>
<p id="no-results" hidden>No strategy matches this filter.</p>
""" % (len(strategies), "".join(rows))
    return body


# --------------------------------------------------------------------------
# HTTP layer
# --------------------------------------------------------------------------


def _safe_join(base_dir, name):
    """Resolve name inside base_dir; return None on any traversal attempt."""
    if not name or "\x00" in name or "\\" in name:
        return None
    candidate = os.path.realpath(os.path.join(base_dir, name))
    base = os.path.realpath(base_dir)
    if candidate != base and not candidate.startswith(base + os.sep):
        return None
    return candidate


class Handler(BaseHTTPRequestHandler):
    server_version = "local"
    sys_version = ""
    protocol_version = "HTTP/1.1"

    # ---- helpers ----
    def _security_headers(self):
        img_src = "'self' data:" if OFFLINE else "'self' https: data:"
        csp = (
            "default-src 'none'; img-src %s; style-src 'self' 'unsafe-inline'; "
            "script-src 'self'; base-uri 'none'; form-action 'none'; frame-ancestors 'none'"
            % img_src
        )
        self.send_header("Content-Security-Policy", csp)
        self.send_header("X-Content-Type-Options", "nosniff")
        self.send_header("X-Frame-Options", "DENY")
        self.send_header("Referrer-Policy", "no-referrer")
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cross-Origin-Resource-Policy", "same-origin")
        self.send_header("Permissions-Policy", "camera=(), microphone=(), geolocation=()")

    def _send(self, status, content_type, body, cache="no-store", extra=None):
        self.send_response(status)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", cache)
        self._security_headers()
        for k, v in (extra or {}).items():
            self.send_header(k, v)
        self.end_headers()
        if self.command != "HEAD":
            self.wfile.write(body)

    def _send_html(self, body_html, status=200):
        self._send(status, "text/html; charset=utf-8", body_html.encode("utf-8"))

    def _not_found(self):
        body = page("Not found", "<h1>404</h1><p>This page does not exist. <a href='/'>Back to the list</a>.</p>",
                    strategy_count=len(self.server.strategies))
        self._send_html(body, status=404)

    # ---- routing ----
    def do_GET(self):
        try:
            self._route()
        except BrokenPipeError:
            pass
        except Exception:
            self._send_html(page("Error", "<h1>500</h1><p>Internal error.</p>"), status=500)

    do_HEAD = do_GET

    def do_POST(self):
        self._send(405, "text/plain; charset=utf-8", b"Method Not Allowed", extra={"Allow": "GET, HEAD"})

    do_PUT = do_DELETE = do_PATCH = do_OPTIONS = do_POST

    def _route(self):
        path = unquote(urlsplit(self.path).path)
        if len(path) > 1024:
            return self._not_found()
        srv = self.server

        if path == "/healthz":
            return self._send(200, "text/plain; charset=utf-8", b"ok")

        if path == "/favicon.ico":
            self.send_response(302)
            self.send_header("Location", "/static/images/awesome-systematic-trading.jpeg")
            self.send_header("Content-Length", "0")
            self._security_headers()
            self.end_headers()
            return None

        if path in MD_PAGES:
            filename, title, lang = MD_PAGES[path]
            file_path = os.path.join(REPO_ROOT, filename)
            if not os.path.isfile(file_path):
                return self._not_found()
            with open(file_path, encoding="utf-8") as f:
                content = render_markdown(f.read())
            active = {"/": "home", "/zh": "zh", "/run-locally": "about"}[path]
            return self._send_html(
                page(title, "<article class='markdown'>%s</article>" % content,
                     active=active, strategy_count=len(srv.strategies))
            )

        if path == "/strategies":
            return self._send_html(
                page("Strategies", strategies_page(srv.strategies),
                     active="strategies", strategy_count=len(srv.strategies))
            )

        if path.startswith("/strategy/"):
            name = path[len("/strategy/"):]
            file_path = _safe_join(STRATEGIES_DIR, name)
            if not file_path or not os.path.isfile(file_path):
                return self._not_found()
            with open(file_path, encoding="utf-8", errors="replace") as f:
                source = f.read()
            meta = next((s for s in srv.strategies if s["file"] == name), None)
            title = meta["title"] if meta else name
            chips = []
            if meta:
                if meta["sharpe"]:
                    chips.append("<span class='chip'>Sharpe %s</span>" % html.escape(meta["sharpe"]))
                if meta["vol"]:
                    chips.append("<span class='chip'>Vol %s</span>" % html.escape(meta["vol"]))
                if meta["rebalancing"]:
                    chips.append("<span class='chip'>%s</span>" % html.escape(meta["rebalancing"]))
                if meta["paper"].startswith(("http://", "https://")):
                    chips.append(
                        "<a class='chip' href='%s' target='_blank' rel='noopener noreferrer'>📄 Paper</a>"
                        % html.escape(meta["paper"], quote=True)
                    )
            body = """
<div class="code-head">
  <div>
    <h1>%s</h1>
    <p class="filemeta"><code>static/strategies/%s</code> · %d lines · QuantConnect LEAN algorithm</p>
    <p class="chips">%s</p>
  </div>
  <div class="code-actions">
    <button id="copy-code" type="button">Copy code</button>
    <a class="button" href="/download/strategy/%s" download>Download .py</a>
    <a class="button" href="/strategies">← All strategies</a>
  </div>
</div>
%s
""" % (
                html.escape(title),
                html.escape(name),
                source.count("\n") + 1,
                "".join(chips),
                quote(name),
                render_code_page(name, source),
            )
            return self._send_html(
                page(title, body, active="strategies", strategy_count=len(srv.strategies))
            )

        if path.startswith("/download/strategy/"):
            name = path[len("/download/strategy/"):]
            file_path = _safe_join(STRATEGIES_DIR, name)
            if not file_path or not os.path.isfile(file_path):
                return self._not_found()
            with open(file_path, "rb") as f:
                data = f.read()
            fname = name if name.endswith(".py") else name + ".py"
            return self._send(
                200, "text/x-python; charset=utf-8", data,
                extra={"Content-Disposition": 'attachment; filename="%s"' % fname.replace('"', "")},
            )

        if path.startswith("/static/images/"):
            name = path[len("/static/images/"):]
            file_path = _safe_join(IMAGES_DIR, name)
            ext = os.path.splitext(path)[1].lower()
            if not file_path or not os.path.isfile(file_path) or ext not in IMAGE_TYPES:
                return self._not_found()
            with open(file_path, "rb") as f:
                data = f.read()
            return self._send(200, IMAGE_TYPES[ext], data, cache="public, max-age=3600")

        if path.startswith("/assets/"):
            name = path[len("/assets/"):]
            file_path = _safe_join(ASSETS_DIR, name)
            ext = os.path.splitext(path)[1].lower()
            if not file_path or not os.path.isfile(file_path) or ext not in ASSET_TYPES:
                return self._not_found()
            with open(file_path, "rb") as f:
                data = f.read()
            return self._send(200, ASSET_TYPES[ext], data, cache="public, max-age=3600")

        return self._not_found()

    def log_message(self, fmt, *args):
        sys.stdout.write("[local] %s - %s\n" % (self.address_string(), fmt % args))


def pick_port(host, preferred):
    for port in [preferred] + list(range(preferred + 1, preferred + 11)):
        try:
            with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
                s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
                s.bind((host, port))
            return port
        except OSError:
            continue
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        s.bind((host, 0))
        return s.getsockname()[1]


def main(argv=None):
    global OFFLINE
    parser = argparse.ArgumentParser(description="Run the %s list locally." % APP_NAME)
    parser.add_argument("--host", default=os.environ.get("ASYST_HOST", "127.0.0.1"),
                        help="bind address (default 127.0.0.1 — keep it local)")
    parser.add_argument("--port", type=int, default=int(os.environ.get("ASYST_PORT", DEFAULT_PORT)),
                        help="preferred port (default %d, auto-fallback if busy)" % DEFAULT_PORT)
    parser.add_argument("--offline", action="store_true",
                        help="strict offline mode: block even the README badge images")
    parser.add_argument("--no-browser", action="store_true",
                        default=os.environ.get("ASYST_NO_BROWSER") == "1",
                        help="do not open the web browser automatically")
    args = parser.parse_args(argv)
    OFFLINE = args.offline

    if not os.path.isdir(STRATEGIES_DIR):
        sys.exit("error: %s not found — run this from a full checkout of the repository" % STRATEGIES_DIR)
    if args.host not in ("127.0.0.1", "localhost", "::1"):
        print("⚠️  WARNING: binding to %r exposes the app beyond this machine." % args.host)

    port = pick_port(args.host, args.port)
    server = ThreadingHTTPServer((args.host, port), Handler)
    server.daemon_threads = True
    server.strategies = load_strategies()

    url = "http://%s:%d" % ("127.0.0.1" if args.host in ("0.0.0.0", "::") else args.host, port)
    print("┌─────────────────────────────────────────────────────")
    print("│ 📈 %s — local app" % APP_NAME)
    print("│ Serving %d strategies + the curated list" % len(server.strategies))
    print("│ → %s   (Ctrl+C to stop)" % url)
    print("└─────────────────────────────────────────────────────")

    if not args.no_browser:
        threading.Timer(0.8, lambda: webbrowser.open(url)).start()

    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nbye 👋")
        server.server_close()


if __name__ == "__main__":
    main()
