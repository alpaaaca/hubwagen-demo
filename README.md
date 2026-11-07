# moksha demo: daily revenue

A [moksha](https://github.com/alpaaaca/moksha) project: one run per day,
`extract_orders` → `daily_revenue` → `revenue_report`, each writing a new
version of its dataset. Source data is `data/orders.csv`; `nightly` runs it
at 03:00 UTC for the day that just ended.

Run it on your machine with `moksha dev`, then on a Kubernetes cluster
(kind) with `helm install` and `moksha deploy`. The same project file,
[moksha.yaml](moksha.yaml), serves both.

| Path | What |
|---|---|
| `moksha.yaml` | the project: its name, how its image is built, its pool of workers (0 to 3) |
| `revenue/` | the pipelines and steps ([pipelines.py](revenue/pipelines.py), [nightly.py](revenue/nightly.py)) |
| `pyproject.toml` | the modules the worker imports (`[tool.moksha]`) |
| `Dockerfile` | the project's image: moksha's worker image and this code |
| `kind/` | a local cluster and registry for the Kubernetes part |

## Setup

Needs Python ≥ 3.12. Download `moksha_0.2.0_<os>_<arch>.tar.gz` (`darwin`
or `linux`, `arm64` or `amd64`) from [the v0.2.0
release](https://github.com/alpaaaca/moksha/releases/tag/v0.2.0); for
example, on an Apple silicon Mac:

```bash
mkdir -p bin
curl -fsSL https://github.com/alpaaaca/moksha/releases/download/v0.2.0/moksha_0.2.0_darwin_arm64.tar.gz | tar -xz -C bin moksha
export PATH=$PWD/bin:$PATH
moksha version
```

Then the Python SDK, in a virtual environment (it isn't on PyPI yet; pip
installs it from the release's tag):

```bash
python3 -m venv .venv
. .venv/bin/activate
pip install "git+https://github.com/alpaaaca/moksha@v0.2.0#subdirectory=sdk/python"
```

## On your machine: `moksha dev`

With the venv active, in this directory:

```bash
moksha dev
```

It starts a server (its state in `.moksha/`, the API and web UI on
http://127.0.0.1:7070) and deploys this project to it as v1: its code in
place, run by the venv's `python3`. In another terminal:

```bash
moksha start daily --param day=2026-10-01 --wait
moksha replay daily --param day=2026-10-01..2026-10-03
```

The pool has no workers while nothing waits (`min: 0`); a run starts one,
a backfill up to three (`max: 3`), and they stop after five minutes with
nothing to run. `moksha dev` prints when.

Things to try:

- **Reuse**: replay the same days again. `extract_orders` runs (it reads
  a source that can change), but its output is identical, so
  `daily_revenue` and `revenue_report` are reused.
- **Code changes**: change `daily_revenue` in
  [revenue/pipelines.py](revenue/pipelines.py) (say, round to whole units:
  `Decimal("1")`) and save. `moksha dev` deploys v2; replay, and it runs
  again because "its code changed", and `revenue_report` because "an
  input changed".
- **Data changes**: add a row for 2026-10-02 to `data/orders.csv` and
  replay: only that day's `daily_revenue` and report run again.
- **What steps print**: the web UI shows it on each run's page; click a
  step for its output alone. `moksha start daily --param day=2026-10-20`
  (no orders that day) logs a warning.
- **Restarts**: Ctrl-C `moksha dev` during a replay and start it again:
  the runs pick up where they were, and finished steps aren't run again.

`rm -rf .moksha` forgets every run and data version.

## On Kubernetes: kind, `helm install`, `moksha deploy`

Needs [kind](https://kind.sigs.k8s.io), kubectl, Helm, and Docker or
podman. Stop `moksha dev` first: both use port 7070.

```bash
./kind/up.sh                   # a cluster "moksha" and a registry at localhost:5001
helm install moksha oci://ghcr.io/alpaaaca/charts/moksha --version 0.2.0 \
  --kube-context kind-moksha -n moksha --create-namespace
kubectl --context kind-moksha -n moksha rollout status deploy/moksha
kubectl --context kind-moksha -n moksha port-forward svc/moksha 7070   # leave it running
```

The chart installs only the server; the server runs what you deploy to
it. In another terminal, here:

```bash
moksha deploy --push
```

It builds the image (`Dockerfile`), shows what would run again, pushes it
to the registry and deploys it by digest. The server makes the pool a
Deployment, `moksha-revenue-default-v1`, with no pods yet. Start a
backfill of two months and watch them come:

```bash
kubectl --context kind-moksha -n moksha get pods -w     # in a third terminal
moksha replay daily --param day=2026-09-01..2026-10-31
```

The first run starts a pod; with 61 runs waiting, the pool grows to
three (`max: 3`), and goes back to none five minutes after the work is
done. `curl -s http://127.0.0.1:7070/v1/pools` shows each decision and
why. The web UI is at http://127.0.0.1:7070, the
same as with `moksha dev`.

Things to try:

- **A new version**: change `daily_revenue` and `moksha deploy --push`
  again. The server creates `moksha-revenue-default-v2` and deletes v1's
  Deployment; its pods finish what they run first. `moksha projects`
  shows what runs.
- **The server restarts**: `kubectl --context kind-moksha -n moksha
  delete pod -l app.kubernetes.io/component=server` during a backfill.
  The port-forward and `moksha replay` stop with the pod; start the
  port-forward again once the new one is ready. Its state is on a
  volume, the workers retry until it is back, and the runs go on: the
  web UI shows them finishing.
- **Remove the project**: `moksha delete revenue` deletes its
  Deployments.

When you're done:

```bash
./kind/down.sh                 # the cluster and the registry
```

The cluster here keeps data versions on the server's volume. For a real
one, give the chart an S3 bucket, and push your images to a registry
your cluster pulls from: moksha's [deploy.md](https://github.com/alpaaaca/moksha/blob/main/docs/deploy.md#kubernetes-the-helm-chart).
