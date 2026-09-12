# Awesome Systematic Trading — local app.
# Minimal, hardened image: stdlib-only server, non-root user, read-only friendly.
FROM python:3.12-slim

WORKDIR /app
COPY README.md README_zh.md RUN_LOCALLY.md ./
COPY static/ ./static/
COPY local_app/ ./local_app/

ENV ASYST_HOST=0.0.0.0 \
    ASYST_PORT=8420 \
    ASYST_NO_BROWSER=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

# Run as the unprivileged "nobody" user — the app only ever reads files.
USER 65534:65534

EXPOSE 8420
HEALTHCHECK --interval=30s --timeout=3s --retries=3 \
  CMD python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8420/healthz', timeout=2)"

CMD ["python", "local_app/server.py"]
