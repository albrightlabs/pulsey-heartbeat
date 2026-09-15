# Pulsey Heartbeat for GitHub Actions

Monitor scheduled workflows with [Pulsey](https://pulseyapp.com) heartbeats. Pulsey alerts you when a run doesn't happen on schedule and, with this action, as soon as a run fails.

## Usage

1. In Pulsey, create a heartbeat with the workflow's schedule and copy its URL.
2. Add the URL as a repository secret, e.g. `PULSEY_HEARTBEAT_URL`.
3. Add this step at the end of the job:

```yaml
on:
  schedule:
    - cron: '0 3 * * *'

jobs:
  nightly:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: ./scripts/nightly-backup.sh

      - uses: albrightlabs/pulsey-heartbeat@v1
        if: always()
        with:
          url: ${{ secrets.PULSEY_HEARTBEAT_URL }}
          status: ${{ job.status }}
```

`if: always()` makes the step run when earlier steps fail, so the failure reaches Pulsey.

## Inputs

| Input | Default | |
|---|---|---|
| `url` | required | The heartbeat URL from Pulsey |
| `status` | `success` | `success` pings the heartbeat; `failure` pings `/fail`, which alerts right away; `cancelled` is skipped unless `report-cancelled` is `true` |
| `message` | a link to the run | Sent with failures and shown in the alert |
| `report-cancelled` | `false` | Treat cancelled runs as failures |
| `retries` | `3` | Retries if Pulsey can't be reached |
| `timeout` | `10` | Seconds per attempt |

Output: `http-status`, the status Pulsey returned (empty when nothing was sent).

If Pulsey can't be reached or returns an error, the step logs a warning and your workflow continues. The heartbeat URL is masked in logs.

## Development

```sh
./test/test.sh
```

The tests run `ping.sh` against a local mock server (needs `bash`, `curl` and `python3`).
