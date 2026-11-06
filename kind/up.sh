#!/bin/sh
# A kind cluster called moksha, and a registry at localhost:5001 that both
# you (moksha deploy --push) and the cluster reach. Docker or podman.
#   ./kind/up.sh      then: helm install … (see the README)
#   ./kind/down.sh    removes both
set -eu
cd "$(dirname "$0")"

if command -v docker >/dev/null 2>&1; then
	rt=docker
elif command -v podman >/dev/null 2>&1; then
	rt=podman
	export KIND_EXPERIMENTAL_PROVIDER=podman
else
	echo "needs docker or podman" >&2
	exit 1
fi

kind get clusters 2>/dev/null | grep -qx moksha || kind create cluster --name moksha --config cluster.yaml

if [ -z "$($rt ps -aq --filter name='^moksha-registry$')" ]; then
	$rt run -d --restart=always -p 127.0.0.1:5001:5000 --network kind --name moksha-registry docker.io/library/registry:2 >/dev/null
fi
# The node pulls localhost:5001/... from the registry container.
$rt exec moksha-control-plane sh -c 'mkdir -p /etc/containerd/certs.d/localhost:5001 &&
	printf "[host.\"http://moksha-registry:5000\"]\n" > /etc/containerd/certs.d/localhost:5001/hosts.toml'

echo "kind cluster moksha (kubectl context kind-moksha), registry localhost:5001"
if [ "$rt" = podman ]; then
	cat <<'NOTE'
podman pushes over HTTPS unless told otherwise. Once, for this registry:
  podman machine ssh "mkdir -p ~/.config/containers/registries.conf.d &&
    printf '[[registry]]\nlocation = \"localhost:5001\"\ninsecure = true\n' > ~/.config/containers/registries.conf.d/moksha-demo.conf &&
    systemctl --user restart podman.service"
(On Linux, without a machine: the same file under ~/.config/containers/registries.conf.d/.)
NOTE
fi
