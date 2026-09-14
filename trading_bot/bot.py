#!/usr/bin/env python3
"""
Awesome Systematic Trading — real-time paper-trading bot.

Executes buy/sell orders INSTANTLY on a simulated (paper) account, driven by
signals from the catalog's strategies computed on LIVE market data, under a
configurable money-management layer. A localhost dashboard lets you watch and
re-configure everything in real time, and shows a live, numbers-in-hand
analysis of the traded asset (gold by default).

SAFETY MODEL — read before use:
  * PAPER TRADING ONLY. No real broker is wired in. The Broker interface is
    the seam where a real adapter could be plugged, deliberately, with your
    own API keys and at your own risk; this repository does not ship one.
  * Educational software, not investment advice. Past performance of the
    catalog strategies does not predict future results.
  * Localhost only (127.0.0.1), stdlib only, no telemetry. POST endpoints
    verify Host/Origin to block cross-site and DNS-rebinding requests.

Data sources (public, keyless): Yahoo Finance charts, Binance spot API —
auto-fallback, 30-min daily-history cache, and a --demo mode (synthetic
random walk) when you are offline.

Runs on Python 3.8+.
"""

import argparse
import html
import json
import math
import os
import random
import sys
import threading
import time
import urllib.error
import urllib.request
import webbrowser
from collections import deque
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlsplit

APP_NAME = "AST Trading Bot"
BOT_DIR = os.path.dirname(os.path.abspath(__file__))
STATE_PATH = os.path.join(BOT_DIR, "state.json")
DEFAULT_PORT = 8430

ASSETS = {
    "GOLD": {"label": "Gold (GC=F / PAXG)", "yahoo": "GC=F", "binance": "PAXGUSDT"},
    "BTC": {"label": "Bitcoin", "yahoo": "BTC-USD", "binance": "BTCUSDT"},
    "SPY": {"label": "S&P 500 ETF (SPY)", "yahoo": "SPY", "binance": None},
}

# name: (type, min, max, default)
CONFIG_FIELDS = {
    "asset": (str, None, None, "GOLD"),
    "start_equity": (float, 1000.0, 1e9, 100000.0),
    "risk_per_trade_pct": (float, 0.1, 10.0, 1.0),
    "vol_target_pct": (float, 1.0, 100.0, 10.0),
    "max_position_pct": (float, 1.0, 100.0, 100.0),
    "stop_loss_pct": (float, 0.5, 50.0, 5.0),
    "daily_max_loss_pct": (float, 0.5, 50.0, 3.0),
    "poll_seconds": (int, 2, 300, 5),
    "signal_minutes": (int, 1, 240, 15),
    "slippage_bps": (float, 0.0, 100.0, 2.0),
    "fee_bps": (float, 0.0, 100.0, 1.0),
    "use_trend": (bool, None, None, True),
    "use_tsmom": (bool, None, None, True),
    "use_skew": (bool, None, None, True),
    "paused": (bool, None, None, False),
}


def default_config():
    return {k: spec[3] for k, spec in CONFIG_FIELDS.items()}


def validate_config(patch, base):
    """Return a new config = base + valid fields of patch (invalid: ignored)."""
    out = dict(base)
    for key, value in patch.items():
        spec = CONFIG_FIELDS.get(key)
        if spec is None:
            continue
        kind, lo, hi, _ = spec
        try:
            if kind is bool:
                out[key] = bool(value)
            elif kind is int:
                out[key] = max(lo, min(hi, int(value)))
            elif kind is float:
                out[key] = max(lo, min(hi, float(value)))
            elif kind is str and key == "asset" and value in ASSETS:
                out[key] = value
        except (TypeError, ValueError):
            continue
    return out


def utcnow():
    return datetime.now(timezone.utc)


# --------------------------------------------------------------------------
# Market data: Yahoo + Binance with fallback, cache, and a demo generator.
# Base URLs are overridable via env for testing behind restricted networks.
# --------------------------------------------------------------------------

YAHOO_BASE = os.environ.get("BOT_YAHOO_BASE", "https://query1.finance.yahoo.com")
BINANCE_BASE = os.environ.get("BOT_BINANCE_BASE", "https://api.binance.com")
_UA = {"User-Agent": "Mozilla/5.0 (X11; Linux x86_64) ast-bot/1.0"}


def _get_json(url, timeout=10):
    req = urllib.request.Request(url, headers=_UA)
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        return json.loads(resp.read().decode("utf-8", "replace"))


class MarketData:
    def __init__(self, demo=False):
        self.demo = demo
        self._lock = threading.Lock()
        self._daily_cache = {}  # asset -> (fetched_at, [closes])
        self._demo_state = {}
        self._rng = random.Random(42)

    # ---- demo generator ----
    def _demo_series(self, asset):
        if asset not in self._demo_state:
            start = {"GOLD": 2400.0, "BTC": 60000.0, "SPY": 520.0}.get(asset, 100.0)
            closes = [start]
            for _ in range(519):
                closes.append(closes[-1] * math.exp(
                    self._rng.gauss(0.0002, 0.011)))
            self._demo_state[asset] = {"closes": closes, "last": closes[-1]}
        return self._demo_state[asset]

    def _demo_tick(self, asset):
        state = self._demo_series(asset)
        state["last"] *= math.exp(self._rng.gauss(0, 0.0006))
        return state["last"]

    # ---- providers ----
    def _yahoo_daily(self, symbol):
        data = _get_json("%s/v8/finance/chart/%s?range=2y&interval=1d"
                         % (YAHOO_BASE, urllib.request.quote(symbol)))
        result = data["chart"]["result"][0]
        closes = result["indicators"]["quote"][0]["close"]
        return [c for c in closes if isinstance(c, (int, float))]

    def _yahoo_last(self, symbol):
        data = _get_json("%s/v8/finance/chart/%s?range=1d&interval=1m"
                         % (YAHOO_BASE, urllib.request.quote(symbol)))
        result = data["chart"]["result"][0]
        price = result.get("meta", {}).get("regularMarketPrice")
        if isinstance(price, (int, float)):
            return float(price)
        closes = [c for c in result["indicators"]["quote"][0]["close"]
                  if isinstance(c, (int, float))]
        return float(closes[-1])

    def _binance_daily(self, symbol):
        data = _get_json("%s/api/v3/klines?symbol=%s&interval=1d&limit=500"
                         % (BINANCE_BASE, symbol))
        return [float(k[4]) for k in data]

    def _binance_last(self, symbol):
        data = _get_json("%s/api/v3/ticker/price?symbol=%s"
                         % (BINANCE_BASE, symbol))
        return float(data["price"])

    def _providers(self, asset):
        info = ASSETS[asset]
        out = []
        if info["yahoo"]:
            out.append(("yahoo", info["yahoo"]))
        if info["binance"]:
            out.append(("binance", info["binance"]))
        return out

    # ---- public API ----
    def daily_closes(self, asset):
        """~2y of daily closes, cached 30 min. Raises RuntimeError offline."""
        if self.demo:
            return list(self._demo_series(asset)["closes"])
        with self._lock:
            cached = self._daily_cache.get(asset)
            if cached and time.time() - cached[0] < 1800:
                return list(cached[1])
        last_error = "no provider"
        for name, symbol in self._providers(asset):
            try:
                closes = (self._yahoo_daily(symbol) if name == "yahoo"
                          else self._binance_daily(symbol))
                if len(closes) >= 30:
                    with self._lock:
                        self._daily_cache[asset] = (time.time(), closes)
                    return list(closes)
                last_error = "%s: short history" % name
            except Exception as exc:  # noqa: BLE001 - fall through to next
                last_error = "%s: %s" % (name, exc)
        raise RuntimeError(last_error)

    def last_price(self, asset):
        if self.demo:
            return self._demo_tick(asset)
        last_error = "no provider"
        for name, symbol in self._providers(asset):
            try:
                return (self._yahoo_last(symbol) if name == "yahoo"
                        else self._binance_last(symbol))
            except Exception as exc:  # noqa: BLE001
                last_error = "%s: %s" % (name, exc)
        raise RuntimeError(last_error)


# --------------------------------------------------------------------------
# Signals from the catalog strategies (computed on daily closes).
# --------------------------------------------------------------------------


def _returns(closes):
    return [closes[i] / closes[i - 1] - 1.0
            for i in range(1, len(closes)) if closes[i - 1]]


def _skewness(values):
    n = len(values)
    if n < 3:
        return 0.0
    mean = sum(values) / n
    m2 = sum((v - mean) ** 2 for v in values) / n
    m3 = sum((v - mean) ** 3 for v in values) / n
    return m3 / (m2 ** 1.5) if m2 > 0 else 0.0


def realized_vol(closes, window=60):
    rets = _returns(closes[-(window + 1):])
    if len(rets) < 10:
        return 0.15
    mean = sum(rets) / len(rets)
    var = sum((r - mean) ** 2 for r in rets) / max(1, len(rets) - 1)
    return max(0.01, math.sqrt(var) * math.sqrt(252))


def compute_signals(closes, last_price, config):
    """Returns (signals, score, realized_vol). Directions: -1 / 0 / +1."""
    signals = []
    closes = closes + [last_price]

    if config["use_trend"]:
        window = min(210, max(40, len(closes) - 1))
        sma = sum(closes[-window:]) / window
        above = (last_price / sma - 1.0) * 100 if sma else 0.0
        signals.append({
            "key": "trend",
            "name": "Trend following (10-month SMA)",
            "source": "asset-class-trend-following.py",
            "direction": 1 if last_price > sma else 0,
            "value": "%+.2f%% vs SMA%d" % (above, window),
            "detail": "Long above the moving average, cash below (long/flat).",
        })

    if config["use_tsmom"]:
        lookback = min(252, len(closes) - 1)
        if lookback >= 120:
            r12 = closes[-1] / closes[-1 - lookback] - 1.0
            signals.append({
                "key": "tsmom",
                "name": "Time-series momentum (12-month)",
                "source": "time-series-momentum-effect.py",
                "direction": 1 if r12 > 0 else -1,
                "value": "%+.2f%% over %dd" % (r12 * 100, lookback),
                "detail": "Long when the trailing 12-month return is "
                          "positive, short when negative.",
            })

    if config["use_skew"]:
        rets = _returns(closes[-253:])
        if len(rets) >= 60:
            skew = _skewness(rets)
            signals.append({
                "key": "skew",
                "name": "Skewness (12-month daily returns)",
                "source": "skewness-effect-in-commodities.py",
                "direction": 1 if skew < 0 else -1,
                "value": "skew %+.2f" % skew,
                "detail": "Buy negative-skew assets, sell positive-skew "
                          "ones.",
            })

    active = [s["direction"] for s in signals]
    score = sum(active) / len(active) if active else 0.0
    return signals, score, realized_vol(closes)


def target_fraction(score, rvol, config):
    """Signed fraction of equity to hold, after money management."""
    if score == 0.0:
        return 0.0
    vol_scale = min(1.5, (config["vol_target_pct"] / 100.0) / rvol)
    frac = score * vol_scale
    cap = config["max_position_pct"] / 100.0
    return max(-cap, min(cap, frac))


# --------------------------------------------------------------------------
# Paper broker: instant fills with slippage + fees. The seam where a real
# broker adapter could be plugged — deliberately not shipped.
# --------------------------------------------------------------------------


class PaperBroker:
    def __init__(self, cash):
        self.cash = cash
        self.qty = 0.0
        self.avg_price = 0.0

    def equity(self, price):
        return self.cash + self.qty * price

    def execute(self, target_qty, price, config, reason):
        delta = target_qty - self.qty
        if abs(delta * price) < max(10.0, self.equity(price) * 0.005):
            return None  # ignore dust rebalances
        side = 1 if delta > 0 else -1
        fill = price * (1 + side * config["slippage_bps"] / 1e4)
        fee = abs(delta) * fill * config["fee_bps"] / 1e4
        self.cash -= delta * fill + fee
        new_qty = self.qty + delta
        if self.qty * new_qty > 0 and abs(new_qty) > abs(self.qty):
            total = self.avg_price * self.qty + fill * delta
            self.avg_price = total / new_qty
        elif new_qty != 0 and self.qty * new_qty <= 0:
            self.avg_price = fill
        self.qty = new_qty
        if abs(self.qty) < 1e-12:
            self.qty, self.avg_price = 0.0, 0.0
        return {
            "ts": utcnow().isoformat(timespec="seconds"),
            "side": "BUY" if side > 0 else "SELL",
            "qty": round(abs(delta), 6),
            "price": round(fill, 4),
            "fee": round(fee, 4),
            "reason": reason,
            "position": round(self.qty, 6),
        }


# --------------------------------------------------------------------------
# Engine
# --------------------------------------------------------------------------


class Engine:
    def __init__(self, market, config):
        self.market = market
        self.lock = threading.Lock()
        self.config = config
        self.broker = PaperBroker(config["start_equity"])
        self.trades = deque(maxlen=200)
        self.equity_hist = deque(maxlen=1500)
        self.price_hist = deque(maxlen=1500)
        self.signals = []
        self.score = 0.0
        self.rvol = 0.15
        self.target_frac = 0.0
        self.price = None
        self.price_ts = None
        self.day = None
        self.day_start_equity = config["start_equity"]
        self.data_error = None
        self.kill_reason = None
        self._last_signal_at = 0.0
        self._stop = threading.Event()
        self.load_state()

    # ---- persistence ----
    def save_state(self):
        with self.lock:
            state = {
                "config": self.config,
                "cash": self.broker.cash,
                "qty": self.broker.qty,
                "avg_price": self.broker.avg_price,
                "trades": list(self.trades),
                "day": self.day,
                "day_start_equity": self.day_start_equity,
            }
        tmp = STATE_PATH + ".tmp"
        try:
            with open(tmp, "w", encoding="utf-8") as f:
                json.dump(state, f)
            os.replace(tmp, STATE_PATH)
        except OSError:
            pass

    def load_state(self):
        try:
            with open(STATE_PATH, encoding="utf-8") as f:
                state = json.load(f)
        except (OSError, ValueError):
            return
        self.config = validate_config(state.get("config", {}), self.config)
        self.broker.cash = float(state.get("cash", self.broker.cash))
        self.broker.qty = float(state.get("qty", 0.0))
        self.broker.avg_price = float(state.get("avg_price", 0.0))
        self.trades.extend(state.get("trades", [])[-200:])
        self.day = state.get("day")
        self.day_start_equity = float(
            state.get("day_start_equity", self.config["start_equity"]))

    def reset(self):
        with self.lock:
            self.broker = PaperBroker(self.config["start_equity"])
            self.trades.clear()
            self.equity_hist.clear()
            self.kill_reason = None
            self.day_start_equity = self.config["start_equity"]
        try:
            os.remove(STATE_PATH)
        except OSError:
            pass

    # ---- trading logic ----
    def _roll_day(self, equity):
        today = utcnow().date().isoformat()
        if self.day != today:
            self.day = today
            self.day_start_equity = equity

    def _risk_checks(self, price):
        cfg = self.config
        broker = self.broker
        equity = broker.equity(price)
        if broker.qty != 0 and broker.avg_price > 0:
            move = (price / broker.avg_price - 1.0) * (1 if broker.qty > 0 else -1)
            if move < -cfg["stop_loss_pct"] / 100.0:
                trade = broker.execute(0.0, price, cfg, "stop-loss")
                if trade:
                    self.trades.appendleft(trade)
        if equity < self.day_start_equity * (1 - cfg["daily_max_loss_pct"] / 100.0):
            trade = self.broker.execute(0.0, price, cfg, "kill-switch")
            if trade:
                self.trades.appendleft(trade)
            self.config["paused"] = True
            self.kill_reason = ("Daily loss limit hit (%.1f%%) — bot paused."
                                % self.config["daily_max_loss_pct"])

    def _refresh_signals(self, price):
        closes = self.market.daily_closes(self.config["asset"])
        self.signals, self.score, self.rvol = compute_signals(
            closes, price, self.config)
        self.target_frac = target_fraction(self.score, self.rvol, self.config)
        self._last_signal_at = time.time()

    def tick(self):
        cfg = self.config
        try:
            price = self.market.last_price(cfg["asset"])
            self.data_error = None
        except RuntimeError as exc:
            self.data_error = str(exc)
            return
        now = utcnow()
        with self.lock:
            self.price, self.price_ts = price, now.isoformat(timespec="seconds")
            equity = self.broker.equity(price)
            self._roll_day(equity)
            self.price_hist.append((now.timestamp(), price))
            self.equity_hist.append((now.timestamp(), equity))
            if not cfg["paused"]:
                self._risk_checks(price)
                stale = time.time() - self._last_signal_at > cfg["signal_minutes"] * 60
                if stale or not self.signals:
                    try:
                        self._refresh_signals(price)
                    except RuntimeError as exc:
                        self.data_error = str(exc)
                        return
                target_qty = self.target_frac * self.broker.equity(price) / price
                trade = self.broker.execute(target_qty, price, cfg, "signal")
                if trade:
                    self.trades.appendleft(trade)
        self.save_state()

    def run(self):
        while not self._stop.is_set():
            started = time.time()
            try:
                self.tick()
            except Exception as exc:  # noqa: BLE001 - keep the loop alive
                self.data_error = "engine: %s" % exc
            elapsed = time.time() - started
            self._stop.wait(max(0.5, self.config["poll_seconds"] - elapsed))

    def stop(self):
        self._stop.set()

    # ---- views ----
    def apply_config(self, patch):
        with self.lock:
            self.config = validate_config(patch, self.config)
            if "paused" in patch and not self.config["paused"]:
                self.kill_reason = None
            self._last_signal_at = 0.0  # recompute promptly with new settings
        self.save_state()

    def snapshot(self):
        with self.lock:
            price = self.price or 0.0
            equity = self.broker.equity(price) if price else self.broker.cash
            upl = ((price - self.broker.avg_price) * self.broker.qty
                   if self.broker.qty and price else 0.0)
            return {
                "app": APP_NAME,
                "demo": self.market.demo,
                "asset": self.config["asset"],
                "asset_label": ASSETS[self.config["asset"]]["label"],
                "price": price,
                "price_ts": self.price_ts,
                "equity": equity,
                "cash": self.broker.cash,
                "position_qty": self.broker.qty,
                "position_avg": self.broker.avg_price,
                "position_upl": upl,
                "day_pnl": equity - self.day_start_equity,
                "score": self.score,
                "target_frac": self.target_frac,
                "realized_vol_pct": self.rvol * 100,
                "signals": self.signals,
                "config": self.config,
                "trades": list(self.trades)[:60],
                "equity_hist": [v for _, v in list(self.equity_hist)[-400:]],
                "price_hist": [v for _, v in list(self.price_hist)[-400:]],
                "data_error": self.data_error,
                "kill_reason": self.kill_reason,
                "assets": {k: v["label"] for k, v in ASSETS.items()},
            }

    def analysis(self):
        snap = self.snapshot()
        cfg = snap["config"]
        lines = []
        if not snap["price"]:
            return ["Waiting for the first market data tick…"]
        lines.append(
            "%s trades at %.2f (as of %s%s). Realized volatility over the "
            "last 60 sessions is %.1f%% annualized."
            % (snap["asset_label"], snap["price"], snap["price_ts"],
               ", DEMO data" if snap["demo"] else "",
               snap["realized_vol_pct"]))
        for s in snap["signals"]:
            stance = {1: "LONG", 0: "FLAT", -1: "SHORT"}[s["direction"]]
            lines.append("%s → %s (%s). %s [%s]"
                         % (s["name"], stance, s["value"], s["detail"],
                            s["source"]))
        lines.append(
            "Composite score %.2f of the %d enabled signals → target "
            "exposure %.0f%% of equity after volatility targeting "
            "(%.0f%% target vs %.1f%% realized, capped at %.0f%%)."
            % (snap["score"], max(1, len(snap["signals"])),
               snap["target_frac"] * 100, cfg["vol_target_pct"],
               snap["realized_vol_pct"], cfg["max_position_pct"]))
        lines.append(
            "Money management: %.1f%% stop-loss from the average entry, "
            "kill-switch at -%.1f%% on the day (equity %.0f vs day start "
            "%.0f), orders filled instantly with %.1f bps slippage and "
            "%.1f bps fees on the paper account."
            % (cfg["stop_loss_pct"], cfg["daily_max_loss_pct"],
               snap["equity"], self.day_start_equity,
               cfg["slippage_bps"], cfg["fee_bps"]))
        if snap["position_qty"]:
            lines.append("Current position: %+.4f units at avg %.2f, "
                         "unrealized P&L %+.2f."
                         % (snap["position_qty"], snap["position_avg"],
                            snap["position_upl"]))
        else:
            lines.append("Currently flat.")
        if snap["kill_reason"]:
            lines.append("⚠ %s" % snap["kill_reason"])
        lines.append("Educational paper trading — not investment advice. "
                     "The term-structure signal from the catalog needs a "
                     "futures curve and is not computed here.")
        return lines


# --------------------------------------------------------------------------
# Dashboard (single-page, inline assets, localhost-only)
# --------------------------------------------------------------------------

PAGE = """<!DOCTYPE html>
<html lang="en"><head>
<meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="referrer" content="no-referrer"><title>__TITLE__</title>
<style>
:root{color-scheme:dark;--bg:#0b0f14;--panel:#121820;--edge:#223042;--fg:#e6edf3;
--muted:#8b98a5;--accent:#31b0ff;--up:#2fbf71;--down:#ff5c5c;--warn:#ffb454}
*{box-sizing:border-box}body{margin:0;background:var(--bg);color:var(--fg);
font:14px/1.5 ui-monospace,SFMono-Regular,Menlo,Consolas,monospace;padding-block:0 40px}
header{display:flex;align-items:center;gap:14px;flex-wrap:wrap;padding:12px 20px;
border-bottom:1px solid var(--edge);position:sticky;top:0;background:var(--bg);z-index:5}
h1{font-size:16px;margin:0}small.tag{border:1px solid var(--edge);border-radius:99px;
padding:2px 10px;color:var(--muted)}#price{font-size:22px;font-weight:700}
#mode{color:var(--warn)} main{max-width:1200px;margin:0 auto;padding:16px;display:grid;
grid-template-columns:2fr 1fr;gap:14px}@media(max-width:900px){main{grid-template-columns:1fr}}
section{background:var(--panel);border:1px solid var(--edge);border-radius:10px;padding:14px 16px}
section h2{font-size:13px;margin:0 0 10px;color:var(--accent);text-transform:uppercase;
letter-spacing:.08em}.cards{display:grid;grid-template-columns:repeat(auto-fit,minmax(150px,1fr));
gap:10px}.card{border:1px solid var(--edge);border-radius:8px;padding:8px 12px}
.card b{display:block;font-size:17px}.card span{color:var(--muted);font-size:12px}
canvas{width:100%;height:90px;display:block;background:#0e141b;border-radius:6px;margin-top:8px}
table{width:100%;border-collapse:collapse;font-size:12.5px}th,td{text-align:left;
padding:5px 8px;border-bottom:1px solid var(--edge)}th{color:var(--muted)}
.pos{color:var(--up)}.neg{color:var(--down)}.flat{color:var(--muted)}
form.cfg{display:grid;grid-template-columns:1fr 1fr;gap:8px}form.cfg label{display:flex;
flex-direction:column;gap:2px;font-size:11.5px;color:var(--muted)}
input,select{background:#0e141b;border:1px solid var(--edge);color:var(--fg);
border-radius:6px;padding:6px 8px;font:inherit}input[type=checkbox]{width:16px;height:16px}
.chk{flex-direction:row!important;align-items:center;gap:8px!important;color:var(--fg)!important}
.btns{display:flex;gap:8px;flex-wrap:wrap;margin-top:10px}button{cursor:pointer;
border:1px solid var(--edge);background:#182230;color:var(--fg);border-radius:7px;
padding:7px 14px;font:inherit}button.primary{background:var(--accent);color:#00131f;
border-color:var(--accent);font-weight:700}button.danger{background:#3a1620;
border-color:#7a2740;color:#ff9c9c}#banner{display:none;margin:10px 20px 0;padding:10px 14px;
border:1px solid var(--warn);border-radius:8px;color:var(--warn)}
#analysis p{margin:0 0 10px;color:#c8d3dc}#analysis p:first-child{color:var(--fg)}
.dis{color:var(--muted);font-size:12px}
</style></head><body>
<header>
  <h1>🤖 __TITLE__</h1><small class="tag" id="assetlabel">—</small>
  <span id="price">—</span><span id="mode"></span>
  <small class="tag">paper account · localhost only</small>
</header>
<div id="banner"></div>
<main>
<div style="display:flex;flex-direction:column;gap:14px">
  <section><h2>Portfolio</h2>
    <div class="cards">
      <div class="card"><b id="equity">—</b><span>Equity</span></div>
      <div class="card"><b id="daypnl">—</b><span>Day P&amp;L</span></div>
      <div class="card"><b id="posqty">—</b><span>Position (units)</span></div>
      <div class="card"><b id="upl">—</b><span>Unrealized P&amp;L</span></div>
      <div class="card"><b id="score">—</b><span>Signal score</span></div>
      <div class="card"><b id="target">—</b><span>Target exposure</span></div>
    </div>
    <canvas id="cprice" height="90"></canvas>
    <canvas id="cequity" height="90"></canvas>
  </section>
  <section><h2>Signals (from the catalog strategies)</h2>
    <table><thead><tr><th>Signal</th><th>Stance</th><th>Value</th></tr></thead>
    <tbody id="signals"></tbody></table>
  </section>
  <section><h2>Real-time analysis</h2><div id="analysis">—</div></section>
  <section><h2>Trades</h2>
    <table><thead><tr><th>Time (UTC)</th><th>Side</th><th>Qty</th><th>Price</th>
    <th>Reason</th><th>Position</th></tr></thead><tbody id="trades"></tbody></table>
  </section>
</div>
<div style="display:flex;flex-direction:column;gap:14px">
  <section><h2>Live configuration</h2>
    <form class="cfg" id="cfg">
      <label class="chk" style="grid-column:1/-1"><input type="checkbox" name="paused"> Paused</label>
      <label style="grid-column:1/-1">Asset <select name="asset" id="assetsel"></select></label>
      <label>Risk / trade % <input name="risk_per_trade_pct" type="number" step="0.1"></label>
      <label>Vol target % <input name="vol_target_pct" type="number" step="0.5"></label>
      <label>Max position % <input name="max_position_pct" type="number" step="1"></label>
      <label>Stop-loss % <input name="stop_loss_pct" type="number" step="0.5"></label>
      <label>Daily max loss % <input name="daily_max_loss_pct" type="number" step="0.5"></label>
      <label>Poll (s) <input name="poll_seconds" type="number" step="1"></label>
      <label>Signals every (min) <input name="signal_minutes" type="number" step="1"></label>
      <label>Slippage (bps) <input name="slippage_bps" type="number" step="0.5"></label>
      <label>Fees (bps) <input name="fee_bps" type="number" step="0.5"></label>
      <label>Start equity <input name="start_equity" type="number" step="1000"></label>
      <label class="chk"><input type="checkbox" name="use_trend"> Trend (10-mo SMA)</label>
      <label class="chk"><input type="checkbox" name="use_tsmom"> TSMOM 12-mo</label>
      <label class="chk"><input type="checkbox" name="use_skew"> Skewness</label>
    </form>
    <div class="btns">
      <button class="primary" id="apply">Apply live</button>
      <button id="pause">Pause</button><button id="resume">Resume</button>
      <button class="danger" id="kill">Flatten + pause</button>
      <button class="danger" id="reset">Reset paper account</button>
    </div>
    <p class="dis">Paper trading on live market data. Educational — not
    investment advice. No real broker is connected.</p>
  </section>
</div>
</main>
<script>
"use strict";
const $=id=>document.getElementById(id);
const fmt=(v,d=2)=>v==null?"—":Number(v).toLocaleString("en-US",{minimumFractionDigits:d,maximumFractionDigits:d});
const cls=v=>v>0?"pos":v<0?"neg":"flat";
let editing=false;
document.querySelectorAll("#cfg input,#cfg select").forEach(el=>{
  el.addEventListener("focus",()=>editing=true);
  el.addEventListener("blur",()=>setTimeout(()=>editing=false,150));});
function spark(id,data,color){const c=$(id),x=c.getContext("2d");
  const w=c.width=c.clientWidth,h=c.height;x.clearRect(0,0,w,h);
  if(!data||data.length<2)return;const mn=Math.min(...data),mx=Math.max(...data),sp=mx-mn||1;
  x.beginPath();data.forEach((v,i)=>{const px=i/(data.length-1)*(w-8)+4,
  py=h-6-((v-mn)/sp)*(h-14);i?x.lineTo(px,py):x.moveTo(px,py);});
  x.strokeStyle=color;x.lineWidth=1.6;x.stroke();
  x.fillStyle=color+"22";x.lineTo(w-4,h-4);x.lineTo(4,h-4);x.closePath();x.fill();}
function fillCfg(cfg,assets){if(editing)return;const f=document.forms.cfg;
  const sel=$("assetsel");if(sel.options.length===0)
    for(const[k,v]of Object.entries(assets)){const o=document.createElement("option");
      o.value=k;o.textContent=v;sel.appendChild(o);}
  for(const el of f.elements){if(!el.name)continue;const v=cfg[el.name];
    if(v===undefined)continue;
    if(el.type==="checkbox")el.checked=!!v;else el.value=v;}}
async function post(url,body){const r=await fetch(url,{method:"POST",
  headers:{"Content-Type":"application/json","X-Bot":"1"},body:JSON.stringify(body)});
  return r.json().catch(()=>({}));}
function readCfg(){const f=document.forms.cfg,out={};for(const el of f.elements){
  if(!el.name)continue;out[el.name]=el.type==="checkbox"?el.checked:el.value;}return out;}
$("apply").onclick=()=>post("/api/config",readCfg());
$("pause").onclick=()=>post("/api/config",{paused:true});
$("resume").onclick=()=>post("/api/config",{paused:false});
$("kill").onclick=()=>{if(confirm("Close any position and pause the bot?"))post("/api/action",{action:"kill"});};
$("reset").onclick=()=>{if(confirm("Reset the paper account and trade log?"))post("/api/action",{action:"reset"});};
async function refresh(){try{
  const s=await(await fetch("/api/state")).json();
  $("assetlabel").textContent=s.asset_label;
  $("price").textContent=s.price?fmt(s.price):"—";
  $("mode").textContent=(s.demo?"DEMO DATA ":"")+(s.config.paused?"· PAUSED":"");
  $("equity").textContent=fmt(s.equity,0);
  const dp=$("daypnl");dp.textContent=(s.day_pnl>=0?"+":"")+fmt(s.day_pnl,0);dp.className=cls(s.day_pnl);
  $("posqty").textContent=fmt(s.position_qty,4);
  const up=$("upl");up.textContent=(s.position_upl>=0?"+":"")+fmt(s.position_upl,0);up.className=cls(s.position_upl);
  $("score").textContent=fmt(s.score,2);
  $("target").textContent=fmt(s.target_frac*100,0)+"%";
  spark("cprice",s.price_hist,"#31b0ff");spark("cequity",s.equity_hist,"#2fbf71");
  $("signals").innerHTML=s.signals.map(g=>{const st=g.direction>0?"LONG":g.direction<0?"SHORT":"FLAT";
    return `<tr><td>${g.name}</td><td class="${cls(g.direction)}">${st}</td><td>${g.value}</td></tr>`;}).join("")
    ||`<tr><td colspan=3 class=flat>no signals enabled</td></tr>`;
  $("trades").innerHTML=s.trades.map(t=>`<tr><td>${t.ts.replace("T"," ").replace("+00:00","")}</td>
    <td class="${t.side==="BUY"?"pos":"neg"}">${t.side}</td><td>${fmt(t.qty,4)}</td>
    <td>${fmt(t.price)}</td><td>${t.reason}</td><td>${fmt(t.position,4)}</td></tr>`).join("")
    ||`<tr><td colspan=6 class=flat>no trades yet</td></tr>`;
  fillCfg(s.config,s.assets);
  const b=$("banner");
  if(s.data_error){b.style.display="block";b.textContent="Market data unavailable: "+s.data_error+" — check your connection, or restart with --demo.";}
  else if(s.kill_reason){b.style.display="block";b.textContent=s.kill_reason;}
  else b.style.display="none";
}catch(e){/* server restarting */}}
async function refreshAnalysis(){try{
  const a=await(await fetch("/api/analysis")).json();
  $("analysis").innerHTML=a.lines.map(l=>`<p>${l.replace(/&/g,"&amp;").replace(/</g,"&lt;")}</p>`).join("");
}catch(e){}}
refresh();refreshAnalysis();
setInterval(refresh,2000);setInterval(refreshAnalysis,15000);
</script></body></html>"""


class Handler(BaseHTTPRequestHandler):
    server_version = "local"
    sys_version = ""
    protocol_version = "HTTP/1.1"

    def _headers(self, status, ctype, length, cache="no-store"):
        self.send_response(status)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(length))
        self.send_header("Cache-Control", cache)
        self.send_header("X-Content-Type-Options", "nosniff")
        self.send_header("X-Frame-Options", "DENY")
        self.send_header("Referrer-Policy", "no-referrer")
        self.send_header(
            "Content-Security-Policy",
            "default-src 'none'; img-src 'self'; style-src 'unsafe-inline'; "
            "script-src 'unsafe-inline'; connect-src 'self'; "
            "frame-ancestors 'none'; base-uri 'none'; form-action 'none'")
        self.end_headers()

    def _send(self, status, ctype, body):
        data = body if isinstance(body, bytes) else body.encode("utf-8")
        self._headers(status, ctype, len(data))
        if self.command != "HEAD":
            self.wfile.write(data)

    def _json(self, payload, status=200):
        self._send(status, "application/json; charset=utf-8",
                   json.dumps(payload))

    def _local_request(self):
        """Anti CSRF / DNS-rebinding: Host must be local; Origin, if any,
        must be a local origin; our JS also sends X-Bot."""
        host = (self.headers.get("Host") or "").split(":")[0]
        if host not in ("127.0.0.1", "localhost", "::1"):
            return False
        origin = self.headers.get("Origin")
        if origin:
            parsed = urlsplit(origin)
            if parsed.hostname not in ("127.0.0.1", "localhost", "::1"):
                return False
        return True

    def do_GET(self):
        try:
            path = urlsplit(self.path).path
            engine = self.server.engine
            if path == "/":
                return self._send(200, "text/html; charset=utf-8",
                                  PAGE.replace("__TITLE__", html.escape(APP_NAME)))
            if path == "/healthz":
                return self._send(200, "text/plain; charset=utf-8", "ok")
            if path == "/api/state":
                return self._json(engine.snapshot())
            if path == "/api/analysis":
                return self._json({"lines": engine.analysis()})
            return self._send(404, "text/plain; charset=utf-8", "not found")
        except BrokenPipeError:
            pass
        except Exception:
            self._send(500, "text/plain; charset=utf-8", "error")

    do_HEAD = do_GET

    def do_POST(self):
        try:
            if not self._local_request() or self.headers.get("X-Bot") != "1":
                return self._json({"error": "forbidden"}, status=403)
            length = min(int(self.headers.get("Content-Length") or 0), 65536)
            try:
                payload = json.loads(self.rfile.read(length) or b"{}")
            except ValueError:
                return self._json({"error": "bad json"}, status=400)
            if not isinstance(payload, dict):
                return self._json({"error": "bad json"}, status=400)
            engine = self.server.engine
            path = urlsplit(self.path).path
            if path == "/api/config":
                engine.apply_config(payload)
                return self._json({"ok": True, "config": engine.config})
            if path == "/api/action":
                action = payload.get("action")
                if action == "kill":
                    engine.apply_config({"paused": True})
                    with engine.lock:
                        if engine.price:
                            trade = engine.broker.execute(
                                0.0, engine.price, engine.config, "manual kill")
                            if trade:
                                engine.trades.appendleft(trade)
                    engine.save_state()
                    return self._json({"ok": True})
                if action == "reset":
                    engine.reset()
                    return self._json({"ok": True})
                return self._json({"error": "unknown action"}, status=400)
            return self._json({"error": "not found"}, status=404)
        except BrokenPipeError:
            pass
        except Exception:
            self._json({"error": "internal"}, status=500)

    def log_message(self, fmt, *args):
        sys.stdout.write("[bot] %s\n" % (fmt % args))


def main(argv=None):
    parser = argparse.ArgumentParser(description=APP_NAME)
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int,
                        default=int(os.environ.get("BOT_PORT", DEFAULT_PORT)))
    parser.add_argument("--demo", action="store_true",
                        help="synthetic offline market data")
    parser.add_argument("--no-browser", action="store_true",
                        default=os.environ.get("ASYST_NO_BROWSER") == "1")
    args = parser.parse_args(argv)

    if args.host not in ("127.0.0.1", "localhost", "::1"):
        print("⚠️  WARNING: binding to %r exposes the bot beyond this machine."
              % args.host)

    engine = Engine(MarketData(demo=args.demo), default_config())
    thread = threading.Thread(target=engine.run, daemon=True)
    thread.start()

    server = ThreadingHTTPServer((args.host, args.port), Handler)
    server.daemon_threads = True
    server.engine = engine

    url = "http://127.0.0.1:%d" % args.port
    print("┌────────────────────────────────────────────────────────")
    print("│ 🤖 %s — PAPER trading (no real broker attached)" % APP_NAME)
    print("│ Live data: Yahoo Finance / Binance%s"
          % ("  [DEMO MODE]" if args.demo else ""))
    print("│ → %s   (Ctrl+C to stop)" % url)
    print("│ Educational software — not investment advice.")
    print("└────────────────────────────────────────────────────────")
    if not args.no_browser:
        threading.Timer(0.8, lambda: webbrowser.open(url)).start()
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        engine.stop()
        engine.save_state()
        print("\nstate saved — bye 👋")
        server.server_close()


if __name__ == "__main__":
    main()
