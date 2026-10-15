FROM ghcr.io/mdw-nl/datavalgen:latest

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

# run as non-root by default: the base image runs as root, which is fine for
# the manual `docker run --user $(id -u):$(id -g)` CLI flow documented in the
# README (that flag overrides this), but a federated/vantage6 orchestrator
# invoking this image directly won't necessarily pass --user.
RUN useradd --no-create-home --uid 1000 --shell /usr/sbin/nologin datavalgen
USER datavalgen
