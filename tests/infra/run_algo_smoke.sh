#!/usr/bin/env bash
# Thin wrapper so the v6-infrastructure-skill's documented GH Actions /
# local workflow pattern ("bash tests/infra/run_algo_smoke.sh") has a single
# stable entrypoint, independent of how the python smoke script evolves.
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/../.."

# Disposable venv, not the system/repo python: per v6-infrastructure-sh's own
# skill doc, infra.sh should never be pointed at a shared virtualenv, and
# system python often has no pip at all (or blocks global installs via
# PEP 668) - a throwaway venv sidesteps both.
VENV_DIR="$(mktemp -d)/venv"
python3 -m venv "$VENV_DIR"
"$VENV_DIR/bin/pip" install --quiet --upgrade pip
"$VENV_DIR/bin/pip" install --quiet vantage6-client
"$VENV_DIR/bin/python" tests/infra/run_algo_smoke.py
