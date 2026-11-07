# The project's image: moksha's worker and this code. The worker imports
# the modules in pyproject.toml ([tool.moksha]).
ARG WORKER_IMAGE=ghcr.io/alpaaaca/moksha-worker:0.2.1
FROM ${WORKER_IMAGE}
COPY pyproject.toml /app/
COPY revenue /app/revenue
COPY data /app/data
