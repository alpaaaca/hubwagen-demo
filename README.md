# moksha demo: a server, and workers "elsewhere"

The revenue example from [moksha](https://github.com/alpaaaca/moksha),
split the way a real setup is: a server with its state and (optionally) an
S3 bucket, and workers that share no files with it.

| Path | What |
|---|---|
| `moksha` | moksha for this demo: the commands below, with the settings from `.env` |
| `.env.example` | the settings: where moksha's source is, the port, the bucket and its credentials |
| `server/moksha.yaml` | the server's config: state in `server/.moksha/`, data in the bucket, API and web UI on `MOKSHA_LISTEN` |
| `elsewhere/revenue/` | the pipelines' code (`revenue/`), source data (`data/orders.csv`) and the workers' config (`moksha.yaml`) |

The configs take what differs per machine from the environment, as
`${MOKSHA_BUCKET:-}` and the like ([moksha's config
variables](https://github.com/alpaaaca/moksha/blob/main/docs/config.md#variables));
`./moksha` loads `.env` into the environment first. Bucket credentials go to
the server only, as the usual `AWS_ACCESS_KEY_ID` and
`AWS_SECRET_ACCESS_KEY`.

## Setup

Needs Go, Node and Python ≥ 3.12, and a checkout of moksha (by default
next to this one):

```bash
git clone https://github.com/alpaaaca/moksha ../moksha
cp .env.example .env      # then fill it in; without MOKSHA_BUCKET, data stays local
./moksha build            # bin/moksha, with the web UI
```

## Run

```bash
./moksha server             # terminal 1: the server (it starts no workers)
./moksha workers            # terminal 2: the workers
./moksha start 2026-10-01   # terminal 3: one run of daily, waiting for it
./moksha replay 2026-10-01..2026-10-03
```

Then open http://127.0.0.1:7171 (or your `MOKSHA_LISTEN`): pipelines,
runs, their steps and what they printed. When the workers first connect,
the `nightly` schedule starts a run for the day that just ended; with no
orders for that day, its report is empty.

## Things to try

- **No worker**: stop the workers and `./moksha start`: after a few seconds
  it says "waiting: no worker is connected …", in the CLI and on the run's
  page. Start the workers again and it runs.
- **Reuse**: run the same day twice: `extract_orders` runs again (its
  source can change), the rest is reused because its inputs are the same.
- **Code changes**: change `daily_revenue` in
  `elsewhere/revenue/revenue/pipelines.py`, restart the workers and replay:
  it runs again because "its code changed".
- **The server restarts while the workers keep going**: Ctrl-C terminal 1
  and start it again; the workers retry until it is back.

`./moksha clean` forgets every run and data version (`server/.moksha`);
files already in an S3 bucket stay there, unreferenced.
