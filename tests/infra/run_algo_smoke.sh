#!/usr/bin/env bash
# Thin wrapper so the v6-infrastructure-skill's documented GH Actions /
# local workflow pattern ("bash tests/infra/run_algo_smoke.sh") has a single
# stable entrypoint, independent of how the python smoke script evolves.
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/../.."

# vantage6-client (via vantage6-common) uses `list | None`-style union type
# hints evaluated eagerly, which only works on Python 3.10+. Whatever `python3`
# resolves to on a given machine isn't reliable (hit Python 3.9 locally), so
# pick explicitly - python3.12 is what v6-infrastructure-sh's own skill doc
# recommends. Override with PYTHON_INTERPRETER=... if you need a specific one.
if [ -z "${PYTHON_INTERPRETER:-}" ]; then
  for candidate in python3.12 python3.11 python3.10; do
    if command -v "$candidate" >/dev/null 2>&1; then
      PYTHON_INTERPRETER="$candidate"
      break
    fi
  done
fi
if [ -z "${PYTHON_INTERPRETER:-}" ]; then
  echo "No Python 3.10+ interpreter found (vantage6-client requires it)." >&2
  echo "Set PYTHON_INTERPRETER explicitly, e.g.: PYTHON_INTERPRETER=python3.12 $0" >&2
  exit 1
fi
echo "Using $PYTHON_INTERPRETER ($("$PYTHON_INTERPRETER" --version))"

# Disposable venv, not the system/repo python: per v6-infrastructure-sh's own
# skill doc, infra.sh should never be pointed at a shared virtualenv, and
# system python often has no pip at all (or blocks global installs via
# PEP 668) - a throwaway venv sidesteps both.
VENV_DIR="$(mktemp -d)/venv"
"$PYTHON_INTERPRETER" -m venv "$VENV_DIR"
"$VENV_DIR/bin/pip" install --quiet --upgrade pip
"$VENV_DIR/bin/pip" install --quiet vantage6-client
"$VENV_DIR/bin/python" tests/infra/run_algo_smoke.py
