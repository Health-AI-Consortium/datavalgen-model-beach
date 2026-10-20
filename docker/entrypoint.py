# Temporary: vantage6 nodes base32-encode env vars ('=' -> '!'), but run-context-py
# v0.0.3 reads RUN_CONTEXT_FILE raw. Delete once datavalgen ships a decoding version.

import base64
import os
import sys

DECODED_VARS = ("RUN_CONTEXT_FILE", "RUN_CONTEXT_FILE_VALIDATE")


def decode(value: str) -> str:
    # plain paths contain '/', never valid base32, so direct `docker run` is unaffected
    try:
        return base64.b32decode(value.replace("!", "=")).decode("utf-8")
    except ValueError:
        return value


for name in DECODED_VARS:
    if name in os.environ:
        os.environ[name] = decode(os.environ[name])

os.execvp("datavalgen", ["datavalgen", *sys.argv[1:]])
