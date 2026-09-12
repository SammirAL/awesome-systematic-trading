# Run this project locally — one click 🖱️

*[Version française plus bas](#lancer-le-projet-en-local--un-seul-clic-)*

This repository ships a tiny local web app that lets you browse the whole
curated list **and** explore the 60+ strategy implementations (search, syntax
highlighting, one-click download) — entirely on your machine.

## Quick start

| Your setup | Do this |
|------------|---------|
| Linux / macOS | double-click **`start.command`** (macOS) or run **`./start.sh`** |
| Windows | double-click **`start.bat`** |
| Docker | run `docker compose up` and open [http://127.0.0.1:8420](http://127.0.0.1:8420) |

The app opens automatically in your browser at `http://127.0.0.1:8420`.
Stop it with `Ctrl+C` (or `docker compose down`).

**Requirements:** Python 3.8+ (already present on macOS and most Linux
distributions) — *or* Docker. Nothing else: no `pip install`, no Node, no
external packages.

## What you get

- **The full list** (English and 中文) rendered as a website, with a working
  table of contents and GitHub-style anchors.
- **A strategy explorer** at `/strategies`: all QuantConnect (LEAN) algorithms
  of this repo with their Sharpe ratio, volatility, rebalancing frequency and
  paper link, filterable as you type.
- **A code viewer** with Python syntax highlighting, line permalinks,
  copy-to-clipboard and `.py` download — ready to drop into
  [QuantConnect LEAN](https://github.com/QuantConnect/Lean) for backtesting.
- **Dark mode**, obviously.

## Options

```bash
./start.sh --port 9000      # preferred port (auto-fallback if busy)
./start.sh --offline        # strict offline mode: block even the badge images
./start.sh --no-browser     # do not auto-open the browser
```

## Security by design 🛡️

This app was built with a security-first mindset:

- **Localhost only.** The server binds to `127.0.0.1` — it is never reachable
  from your network. (The Docker port mapping is also pinned to `127.0.0.1`.)
- **Zero dependencies.** 100 % Python standard library: no supply-chain
  exposure, no CDN, nothing to `pip install`, fully auditable in one file
  ([`local_app/server.py`](./local_app/server.py)).
- **No telemetry.** Nothing is collected, nothing phones home. The only
  external requests are the badge images already embedded in the README, and
  `--offline` blocks even those via CSP.
- **Hardened HTTP layer.** GET/HEAD only, strict path-traversal guards and
  file-type allowlists, all content HTML-escaped, plus modern response
  headers: `Content-Security-Policy`, `X-Content-Type-Options: nosniff`,
  `X-Frame-Options: DENY`, `Referrer-Policy: no-referrer`.
- **Hardened container.** Non-root user, read-only filesystem,
  `cap_drop: ALL`, `no-new-privileges`, healthcheck included.

## Troubleshooting

- **"Python 3 is required"** → install it from
  [python.org/downloads](https://www.python.org/downloads/) (on Windows, tick
  *“Add python.exe to PATH”*), or use the Docker route.
- **Port already in use** → the app picks the next free port automatically and
  prints the URL; or force one with `--port`.
- **Badges don't load** → they come from `img.shields.io` / `badgen.net`; with
  no internet (or `--offline`) the rest of the app works fully.

---

# Lancer le projet en local — un seul clic 🖱️

Ce dépôt inclut une petite application web locale pour parcourir toute la
liste **et** explorer les 60+ implémentations de stratégies (recherche,
coloration syntaxique, téléchargement) — entièrement sur votre machine.

## Démarrage rapide

| Votre environnement | Action |
|---------------------|--------|
| Linux / macOS | double-cliquez **`start.command`** (macOS) ou lancez **`./start.sh`** |
| Windows | double-cliquez **`start.bat`** |
| Docker | `docker compose up` puis ouvrez [http://127.0.0.1:8420](http://127.0.0.1:8420) |

L'application s'ouvre automatiquement dans votre navigateur sur
`http://127.0.0.1:8420`. Arrêt : `Ctrl+C` (ou `docker compose down`).

**Prérequis :** Python 3.8+ (déjà présent sur macOS et la plupart des Linux)
— *ou* Docker. Rien d'autre : pas de `pip install`, pas de Node, aucun paquet
externe.

## Sécurité par conception 🛡️

- **Localhost uniquement** : le serveur écoute sur `127.0.0.1`, jamais exposé
  au réseau (le port Docker est aussi épinglé sur `127.0.0.1`).
- **Zéro dépendance** : 100 % bibliothèque standard Python — aucune exposition
  à la chaîne d'approvisionnement logicielle, auditable dans un seul fichier.
- **Aucune télémétrie** : rien n'est collecté ; `--offline` bloque même les
  badges du README via CSP.
- **Couche HTTP durcie** : GET/HEAD uniquement, protections anti path
  traversal, listes blanches de types de fichiers, contenu échappé, en-têtes
  `CSP`, `nosniff`, `X-Frame-Options: DENY`, `Referrer-Policy: no-referrer`.
- **Conteneur durci** : utilisateur non-root, système de fichiers en lecture
  seule, `cap_drop: ALL`, `no-new-privileges`.
