# Subtensor portfolio chart: zero-fill before the first history point

Date: 2026-10-21
Status: approved for implementation

## Problem

The "Your Bittensor" header chart renders only the points the Bittensor backend returns
for `GET /v1/bittensor/portfolio/history/search`. The backend samples a server-owned
window on a fixed grid and, by contract, omits every grid instant without a provider
bucket; it never fabricates or carries values forward. The open bucket of the current
hour is marked `completed: false` and the client replaces it with live chain state.

For an account that tao.app started tracking recently (for
`5CLpYny5hRM2NFNBAge6cnVC1TmWE8LYWgefuEhjTquLxA9S` tracking began at 11:00 UTC on
2026-10-21), the response holds one or two points on 1D, 7D and 30D and no points on
90D. The client then draws a two-point line on 1D and 7D, which stretches one hour
across the whole chart, and shows "Chart unavailable" on 30D and 90D because fewer than
two points remain after dropping the open bucket.

Backend and infrastructure were verified healthy; the gap is in client presentation.

## Decision

Fix on the client. The backend contract deliberately leaves gap handling to clients.
iOS changes now; Android follows the same rule in its own repository.

## Rule

`SubtensorPortfolioValueSeriesCalculator.calculate` builds the series on the window
grid instead of on the returned points.

1. Grid: instants from `window.start` to `window.end` inclusive with the period step
   (1 h for `ONE_DAY` and `SEVEN_DAYS`, 4 h for `THIRTY_DAYS`, 8 h for `NINETY_DAYS`),
   the same grid the backend samples.
2. A grid instant takes the completed backend point whose timestamp lies in
   `(instant - step, instant]` when one exists.
3. A grid instant earlier than the first completed backend point is a zero point:
   0 TAO and 0 fiat.
4. A grid instant later than the first completed point with no bucket carries the last
   known TAO value forward. Fiat is recomputed from the TAO fiat history when the
   calculator has one, otherwise the last fiat value is carried as well.
5. Grid instants at or after `now` are dropped. The live point from chain state is
   appended as today, so the open bucket is still replaced by live data.
6. The change over the period keeps its current rule: it is hidden when the first
   point of the series has no positive fiat value, so a series that starts at zero
   shows no percentage.

## Consequences on screen

- 30D for the account above: a flat zero line until 11:00 UTC on 2026-10-21, then a
  jump to 12.44 TAO. "Chart unavailable" disappears.
- 90D with an empty response: zeros across the window and a jump at the live point.
- "Chart unavailable" remains only for a failed history load and for a portfolio that
  cannot be fully priced.

## Out of scope

- The backend contract and service.
- The position screen chart (`SubtensorPosition`), which is driven by alpha price history.
- Android, which gets its own change under this rule.

## Known limitation

The jump marks the moment tao.app began tracking the account, not necessarily the
moment of the stake. For stake placed through Nova they nearly coincide, because the
app queries history right after the extrinsic. For an imported wallet with older stake
the first non-zero point is the tracking start.

## Testing

Unit tests in `SubtensorPortfolioValueSeriesCalculatorTests`:

- a single open bucket on 30D yields the zero grid plus the live point;
- a single completed point on 1D yields zeros before it, the point, then the live point;
- a gap inside the series carries the previous value forward;
- an empty 90D response yields the zero grid plus the live point;
- the change is hidden when the series starts at zero.

Manual check: screenshots of 1D, 7D, 30D and 90D on the account above in a Dev build.
