# Example: daily revenue (v2, Python)

One run per day: `extract_orders` → `daily_revenue` → `revenue_report`,
each writing a new version of its dataset (CSV and text files). Source data: `data/orders.csv`. `nightly`
([revenue/nightly.py](revenue/nightly.py)) runs it on a schedule: at 03:00
UTC, for the day that just ended.

Run it with `../../moksha.sh` (see the demo's [README](../../README.md)):

```bash
./moksha.sh server     # from the demo's root, terminal 1
./moksha.sh workers    # terminal 2
./moksha.sh replay 2026-10-01..2026-10-03
```

[moksha.yaml](moksha.yaml) starts the workers (`py-1`,
`py-2`, …). To run one by hand instead, from this directory:
`PYTHONPATH=<moksha>/sdk/python/src python3 -m moksha.worker --server http://127.0.0.1:7171`.
It imports the modules listed in [pyproject.toml](pyproject.toml).

What to try:

1. Replay the same days again: `extract_orders` runs (it isn't memoized:
   it reads a source that can change), but its output is identical, so
   `daily_revenue` and `revenue_report` are **reused**.
2. Change `daily_revenue` (say, round to whole units: `Decimal("1")`),
   restart the worker and replay: it runs again because "its code changed
   (py-… → py-…)", and `revenue_report` because "an input changed".
3. Kill a worker (`kill -9 <pid>`; `./moksha.sh workers` prints them): it is
   restarted. Ctrl-C `./moksha.sh server` and start it again: the workers
   keep going and retry until it is back.
4. Add a row for 2026-10-02 to `data/orders.csv` and replay: only that
   day's `daily_revenue` and report run again ("an input changed").

5. Watch what the steps print and log: the web UI (http://127.0.0.1:7171/)
   shows it on each run's page; click a step for its output only. Start a
   day with no orders (`./moksha.sh start 2026-10-20`) for a warning.

In moksha's repository, `sdk/python/tests/test_example.py` runs this
example as a test.
