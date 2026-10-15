#!/usr/bin/env bash
# Thin wrapper so the v6-infrastructure-skill's documented GH Actions /
# local workflow pattern ("bash tests/infra/run_algo_smoke.sh") has a single
# stable entrypoint, independent of how the python smoke script evolves.
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/../.."

python3 -m pip install --quiet vantage6-client
python3 tests/infra/run_algo_smoke.py
