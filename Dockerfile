# Pinned by digest, not `:latest` - a floating tag means every build could
# silently pull a different base image (and run_context/safe_validate
# behavior) than the one this Dockerfile was tested against. This is
# amd64-only upstream (no multi-arch manifest list to lose by pinning).
# To update: `docker buildx imagetools inspect ghcr.io/mdw-nl/datavalgen:latest`
# and swap in the new digest deliberately.
FROM ghcr.io/mdw-nl/datavalgen@sha256:3ff5e0521b0f6343e9242483c55c4ed1934c318abc59f313e70847a5ea7ddff9

# default model and factory
ENV DATAVALGEN_MODEL=beach_lung
ENV DATAVALGEN_FACTORY=beach_lung

# pins datavalgen's safe_validate (federated/vantage6) entrypoint to this
# package's own models, as required by datavalgen itself: without this,
# safe_validate refuses to run rather than guess which distribution's models
# to trust.
ENV DATAVALGEN_DISTRIBUTION=datavalgen-model-beach

COPY ./src /app/datavalgen-model-beach/src
COPY ./pyproject.toml /app/datavalgen-model-beach/pyproject.toml

# install beach data model package, where already-installed datavalgen can
# find models and factories via python entry-points
RUN pip install --no-cache-dir /app/datavalgen-model-beach

# temporary: decodes vantage6's base32-encoded env vars before exec'ing
# datavalgen (see docker/entrypoint.py); revert to the base image's
# ENTRYPOINT ["datavalgen"] once upstream run-context-py decodes them itself
COPY ./docker/entrypoint.py /app/datavalgen-model-beach/entrypoint.py
ENTRYPOINT ["python", "/app/datavalgen-model-beach/entrypoint.py"]
