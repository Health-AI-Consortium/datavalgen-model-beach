#!/usr/bin/env python3
"""Lean vantage6 smoke test for the datavalgen-model-beach algorithm.

Unlike the fan-out/master-aggregation algorithms elsewhere in STRATA-FIT,
safe_validate is a single, per-organization call: no master task, no child
tasks to collect. This submits one task to each of the two nodes defined in
tests/infra/nodes.env (one with valid data, one with one bad row) and checks:

- the valid-data node reports num_errors == 0
- the invalid-data node reports num_errors == 1
- neither node's raw result payload ever contains the bad row's actual
  values -- the whole point of safe_validate over a federated connection.

Patterns (Client usage, decode_result, polling) are adapted from
strata-fit-v6-statistics-py/tests/infra/run_algo_smoke.py, simplified for a
single-call algorithm with no master/child relationship.
"""
from __future__ import annotations

import base64
import json
import os
import sys
import time
from typing import Any

from vantage6.client import Client

TERMINAL_STATUSES = {
    "completed",
    "crashed",
    "failed",
    "cancelled",
    "non-existing Docker image",
}

# Values that must never appear in a federated result payload, drawn from
# tests/fixtures/invalid.csv's bad row.
FORBIDDEN_SUBSTRINGS = ["T5c", "PT_TEST_0002", "patient_t_stage"]


def env_int(name: str, default: int) -> int:
    raw = os.getenv(name)
    return int(raw) if raw is not None else default


def decode_result(value: Any) -> tuple[Any, str]:
    """Returns (decoded_value, raw_text) so callers can scan raw_text for leaks."""
    if value is None or isinstance(value, dict):
        return value, json.dumps(value)
    if not isinstance(value, str):
        raw = str(value)
        return {"raw": raw}, raw
    try:
        raw = base64.b64decode(value).decode("utf-8")
        return json.loads(raw), raw
    except Exception:
        pass
    try:
        return json.loads(value), value
    except Exception:
        return {"raw": value}, value


def authenticate_node_user(client: Client, node_name: str) -> None:
    client.authenticate(f"{node_name}-user", f"{node_name}-password")
    client.setup_encryption(None)


def wait_for_terminal(client: Client, task_id: int, timeout_s: int) -> str:
    status = None
    deadline = time.time() + timeout_s
    while time.time() < deadline:
        current = client.task.get(task_id).get("status")
        if current != status:
            print(f"task {task_id} status: {current}")
            status = current
        if current in TERMINAL_STATUSES:
            return current
        time.sleep(2)
    raise TimeoutError(f"Task {task_id} did not finish before timeout")


def run_one(client: Client, *, node_name: str, collab_id: int, org_id: int, image: str, timeout_s: int) -> tuple[dict, str]:
    authenticate_node_user(client, node_name)
    task = client.task.create(
        collaboration=collab_id,
        organizations=[org_id],
        name=f"datavalgen-beach-smoke-{node_name}",
        image=image,
        description="datavalgen-model-beach safe_validate smoke test",
        input_={"method": "safe_validate", "kwargs": {}},
        databases=[{"label": "default"}],
    )
    task_id = task["id"]
    print(f"created task {task_id} on node '{node_name}'")

    status = wait_for_terminal(client, task_id, timeout_s)
    if status != "completed":
        raise RuntimeError(f"Task {task_id} on '{node_name}' finished with status '{status}'")

    rows = client.result.from_task(task_id).get("data", [])
    if not rows:
        raise RuntimeError(f"Task {task_id} on '{node_name}' has no results")
    decoded, raw_text = decode_result(rows[0].get("result"))
    if not isinstance(decoded, dict) or "num_errors" not in decoded:
        raise AssertionError(f"'{node_name}' result missing num_errors: {decoded}")
    return decoded, raw_text


def main() -> None:
    host = os.getenv("V6_SERVER_HOST", "http://localhost")
    port = env_int("V6_SERVER_PORT", 5070)
    api_path = os.getenv("V6_API_PATH", "/api")
    collaboration_name = os.getenv("V6_COLLABORATION_NAME", "datavalgen-beach-ci")
    image = os.environ["V6_ALGO_IMAGE"]
    timeout_s = env_int("V6_TASK_TIMEOUT_S", 300)

    client = Client(host, port, api_path)
    authenticate_node_user(client, "siteclean")
    collab = next(
        item for item in client.collaboration.list()["data"] if item["name"] == collaboration_name
    )
    org_map = {org["name"]: org["id"] for org in client.organization.list()["data"]}

    clean_result, _ = run_one(
        client,
        node_name="siteclean",
        collab_id=collab["id"],
        org_id=org_map["siteclean"],
        image=image,
        timeout_s=timeout_s,
    )
    if clean_result["num_errors"] != 0:
        raise AssertionError(f"Expected 0 errors from 'siteclean', got {clean_result}")
    print(f"siteclean OK: {clean_result}")

    bad_result, bad_raw = run_one(
        client,
        node_name="sitebad",
        collab_id=collab["id"],
        org_id=org_map["sitebad"],
        image=image,
        timeout_s=timeout_s,
    )
    if bad_result["num_errors"] != 1:
        raise AssertionError(f"Expected 1 error from 'sitebad', got {bad_result}")
    for needle in FORBIDDEN_SUBSTRINGS:
        if needle in bad_raw:
            raise AssertionError(
                f"Federated result leaked raw data ('{needle}' found in payload): {bad_raw}"
            )
    print(f"sitebad OK (no leakage): {bad_result}")


if __name__ == "__main__":
    main()
