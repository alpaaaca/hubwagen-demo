#!/bin/sh
# Removes what kind/up.sh made: the cluster and the registry.
set -u
if command -v docker >/dev/null 2>&1; then rt=docker; else rt=podman; export KIND_EXPERIMENTAL_PROVIDER=podman; fi
kind delete cluster --name moksha
$rt rm -f moksha-registry >/dev/null 2>&1 && echo "removed registry moksha-registry"
