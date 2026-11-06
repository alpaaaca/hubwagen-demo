#!/bin/sh
# moksha for this demo: its commands, with the settings from .env (see
# .env.example).
#
#   ./moksha.sh build           build bin/moksha from $MOKSHA_SRC (Go and Node)
#                               (without bin/moksha, the moksha on PATH is used)
#   ./moksha.sh server          the server (terminal 1)
#   ./moksha.sh workers         the workers (terminal 2)
#   ./moksha.sh start [day]     one run of daily, waiting for it (default day: 2026-10-01)
#   ./moksha.sh replay [days]   a run per day (default: 2026-10-01..2026-10-03)
#   ./moksha.sh clean           forget all runs and data versions (server/.moksha)
#   ./moksha.sh ARGS...         any other moksha command, against the server
set -eu

root=$(cd "$(dirname "$0")" && pwd)
cd "$root"
if [ ! -f .env ]; then
	echo "no .env: cp .env.example .env, then fill it in" >&2
	exit 1
fi
set -a
. ./.env
set +a

: "${MOKSHA_SRC:=../moksha}"
: "${MOKSHA_LISTEN:=127.0.0.1:7171}"
case "$MOKSHA_SRC" in /*) src=$MOKSHA_SRC ;; *) src=$root/$MOKSHA_SRC ;; esac
# The configs read the rest (${MOKSHA_BUCKET}, ...) from the environment.
# The workers' PYTHONPATH: the SDK in $MOKSHA_SRC, or none (an installed SDK).
if [ -z "${MOKSHA_SDK:-}" ] && [ -d "$src/sdk/python/src" ]; then
	MOKSHA_SDK=$src/sdk/python/src
fi
export MOKSHA_SDK="${MOKSHA_SDK:-}"
server_url=http://$MOKSHA_LISTEN

# bin/moksha if it was built, else the moksha on PATH (a release binary).
need_bin() {
	if [ -x "$root/bin/moksha" ]; then
		bin=$root/bin/moksha
	elif bin=$(command -v moksha); then
		:
	else
		echo "no moksha: put a release binary on PATH, or run ./moksha.sh build" >&2
		exit 1
	fi
}

cmd=${1:-}
[ $# -gt 0 ] && shift
case "$cmd" in
build)
	if [ ! -d "$src" ]; then
		echo "MOKSHA_SRC: $src is not a directory (clone https://github.com/alpaaaca/moksha there)" >&2
		exit 1
	fi
	bin=$root/bin/moksha
	mkdir -p bin
	(cd "$src/ui" && npm ci)
	(cd "$src" && go generate ./internal/webui && go build -o "$bin" .)
	"$bin" version
	;;
server)
	need_bin
	cd server
	exec "$bin" server --config moksha.yaml "$@"
	;;
workers)
	need_bin
	# The workers get no bucket credentials: they reach the data through the server.
	unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY
	cd elsewhere/revenue
	exec "$bin" workers --config moksha.yaml "$@"
	;;
start)
	need_bin
	exec "$bin" start daily --server "$server_url" --param "day=${1:-2026-10-01}" --wait
	;;
replay)
	need_bin
	exec "$bin" replay daily --server "$server_url" --param "day=${1:-2026-10-01..2026-10-03}"
	;;
clean)
	rm -rf server/.moksha
	echo "removed server/.moksha (runs, catalog, local data versions); files in an S3 bucket stay"
	;;
""|help|-h|--help)
	sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'
	;;
*)
	need_bin
	exec "$bin" "$cmd" "$@" --server "$server_url"
	;;
esac
