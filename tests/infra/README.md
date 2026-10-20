# Federated (vantage6) infra smoke test

This is the heavier, end-to-end lane: a real local vantage6 server + two
nodes, driven by the external
[`v6-infrastructure-sh`](https://github.com/mdw-nl/v6-infrastructure-sh)
harness, running the actual `datavalgen-model-beach` image as a task.

Run this **after** the fast local lane already passes (building the image
and the `RUN_CONTEXT_FILE` smoke tests in `.github/workflows/ci.yml` / the
`Verification` steps in the README) — it's slow, needs Docker, and pulls
images from GHCR, so it's not a substitute for those, only a confirmation
that the whole federated path works through a real vantage6 node, not just
a direct `docker run`.

Two nodes are configured (`tests/infra/nodes.env`):

- `siteclean` — `data/202604_synthetic/splits_by_centre/maastricht.csv` (valid), expect `num_errors: 0`
- `sitebad` — `tests/fixtures/invalid.csv` (one bad row), expect `num_errors: 1`, and the result must not contain that row's values anywhere.

## Local run

```bash
# from this repo's root
ALG_ROOT="$(pwd)"

# Only matters on non-amd64 hosts (e.g. Apple Silicon, arm64 Linux): the
# vantage6 server-lite/node-lite images and datavalgen's own base image are
# amd64-only. Without this, `infra.sh up`'s plain `docker pull` for an
# image never pulled before fails outright with "no matching manifest for
# linux/arm64/...", since the fallback-to-emulation logic in infra.sh only
# kicks in *after* a pull already succeeded (it handles run-time
# architecture mismatches, not pull-time manifest resolution). Harmless to
# export unconditionally - a no-op on a native amd64 host.
export DOCKER_DEFAULT_PLATFORM=linux/amd64

# Outside the repo on purpose - this is a clone of a whole separate project,
# not something that belongs inside datavalgen-model-beach's own working tree.
INFRA_DIR="$(mktemp -d)/v6-infra"
git clone https://github.com/mdw-nl/v6-infrastructure-sh.git "$INFRA_DIR"
cd "$INFRA_DIR"
# Pinned to the same commit as .github/workflows/infra.yml's INFRA_SHA -
# keep both in sync if you deliberately bump it.
git checkout fcb0f2bf5782a1528df0cefa7d2ef5e4b8e86c5f

sed "s#__REPO_ROOT__#$ALG_ROOT#g" "$ALG_ROOT/tests/infra/nodes.env" > infrastructure/nodes.env
cp "$ALG_ROOT/tests/infra/config.env" infrastructure/config.env

cd infrastructure
PYTHON_INTERPRETER=python3.12 ./infra.sh preflight
PYTHON_INTERPRETER=python3.12 ENVIRONMENT=CI UI_ENABLED=false ./infra.sh up

V6_ALGO_IMAGE=datavalgen-model-beach:ci \
  bash "$ALG_ROOT/tests/infra/run_algo_smoke.sh"

PYTHON_INTERPRETER=python3.12 ENVIRONMENT=CI UI_ENABLED=false ./infra.sh down
```

`run_algo_smoke.sh` pushes the locally-built image into a small disposable
local registry container (`v6-local-registry`, port 5001 by default) before
submitting any tasks — vantage6's node does an unconditional `docker pull`
for whatever image a task names, which fails for a purely local-only image.
That registry container is left running (`--restart unless-stopped`) for
reuse across runs; `docker rm -f v6-local-registry` to clean it up.

See `v6-infrastructure-sh`'s own `.skills/v6-infrastructure-skill/SKILL.md`
for the full option set, troubleshooting, and the GitHub Actions pattern
this is meant to slot into.

> [!NOTE]
> This lane has not been executed end-to-end as part of adding it (this
> sandbox's containers have no outbound network, so neither the vantage6
> images nor the algorithm image's own dependencies can be pulled/installed
> here). It's written to closely match
> `strata-fit-v6-statistics-py/tests/infra/run_algo_smoke.py`, a proven
> working example against the same harness, simplified for an algorithm
> that's a single per-organization call instead of a master/child fan-out.
> Treat the first real run (local, or in CI with network access) as the
> actual verification, and expect to iron out small issues (API shapes,
> timeouts) against a live server.
