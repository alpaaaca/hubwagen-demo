# moksha demo: a server, and workers "elsewhere"

The revenue example from [moksha](https://github.com/alpaaaca/moksha),
split the way a real setup is: a server with its state and (optionally) an
S3 bucket, and workers that share no files with it.

| Path | What |
|---|---|
| `moksha.sh` | moksha for this demo: the commands below, with the settings from `.env` |
| `.env.example` | the settings: the port, the bucket and its credentials, where moksha's source is (if you build it) |
| `server/moksha.yaml` | the server's config: state in `server/.moksha/`, data in the bucket, API and web UI on `MOKSHA_LISTEN` |
| `elsewhere/revenue/` | the pipelines' code (`revenue/`), source data (`data/orders.csv`) and the workers' config (`moksha.yaml`) |

The configs take what differs per machine from the environment, as
`${MOKSHA_BUCKET:-}` and the like ([moksha's config
variables](https://github.com/alpaaaca/moksha/blob/main/docs/config.md#variables));
`./moksha.sh` loads `.env` into the environment first. Bucket credentials go to
the server only, as the usual `AWS_ACCESS_KEY_ID` and
`AWS_SECRET_ACCESS_KEY`.

## Setup

Needs Python ≥ 3.12 and moksha: a release binary and the Python SDK, or
both from a checkout of moksha's source.

### With a release (no Go or Node)

Download `moksha_0.1.1_<os>_<arch>.tar.gz` (`darwin` or `linux`, `arm64`
or `amd64`) from [the v0.1.1
release](https://github.com/alpaaaca/moksha/releases/tag/v0.1.1) and put
`moksha` in `bin/` here (or anywhere on your `PATH`); for example, on an
Apple silicon Mac:

```bash
mkdir -p bin
curl -fsSL https://github.com/alpaaaca/moksha/releases/download/v0.1.1/moksha_0.1.1_darwin_arm64.tar.gz | tar -xz -C bin moksha
bin/moksha version
```

Then the Python SDK, in a virtual environment the workers run in (it isn't
on PyPI; pip installs it from the release's tag):

```bash
python3 -m venv .venv
. .venv/bin/activate
pip install "git+https://github.com/alpaaaca/moksha@v0.1.1#subdirectory=sdk/python"
cp .env.example .env         # then fill it in; without MOKSHA_BUCKET, data stays local
```

Activate the venv (`. .venv/bin/activate`) in the terminal you start the
workers in.

### From source

Needs Go and Node too, and a checkout of moksha (by default next to this
one); the workers then use the SDK from it, with no venv:

```bash
git clone https://github.com/alpaaaca/moksha ../moksha
cp .env.example .env         # then fill it in; MOKSHA_SRC if the checkout is elsewhere
./moksha.sh build            # bin/moksha, with the web UI
```

## Run

```bash
./moksha.sh server             # terminal 1: the server (it starts no workers)
./moksha.sh workers            # terminal 2: the workers (with the venv active)
./moksha.sh start 2026-10-01   # terminal 3: one run of daily, waiting for it
./moksha.sh replay 2026-10-01..2026-10-03
```

Then open http://127.0.0.1:7171 (or your `MOKSHA_LISTEN`): pipelines,
runs, their steps and what they printed. When the workers first connect,
the `nightly` schedule starts a run for the day that just ended; with no
orders for that day, its report is empty.

## Things to try

- **No worker**: stop the workers and `./moksha.sh start`: after a few seconds
  it says "waiting: no worker is connected …", in the CLI and on the run's
  page. Start the workers again and it runs.
- **Reuse**: run the same day twice: `extract_orders` runs again (its
  source can change), the rest is reused because its inputs are the same.
- **Code changes**: change `daily_revenue` in
  `elsewhere/revenue/revenue/pipelines.py`, restart the workers and replay:
  it runs again because "its code changed".
- **The server restarts while the workers keep going**: Ctrl-C terminal 1
  and start it again; the workers retry until it is back.

`./moksha.sh clean` forgets every run and data version (`server/.moksha`);
files already in an S3 bucket stay there, unreferenced.
