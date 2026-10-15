# NovaAuth reviewer guide

This change aligns shared bearer authentication with the supplied profile-3 contract in
[nova-infrastructure PR 38](https://github.com/novasamatech/nova-infrastructure/pull/38)
and simplifies authentication recovery. One host-owned installation and current
bearer serve Analytics and Bittensor. Failed authentication completes the caller's operation;
each feature decides what happens next.

## Protocol corrections

Issuance previously appended `bittensor-read` to the signed preimage. It now commits to the
canonical origin and API major 1, with no flow or scope, so the same bearer authorizes ordinary
protected GET, HEAD and POST requests. Auth validates transport syntax and origin; consumers
and the server validate business routes and payloads.

Bittensor reads previously used `/v1/bittensor/profile-3/...`; reads and account searches now
use `/v1/bittensor/...`. The removed root-yield endpoint returns unavailable/cache miss locally,
and its optional yield service returns `nil` without networking. Alpha yield rejects netuid 0
locally, preserving root staking screens without inventing a replacement rate.

HEAD denial recognition no longer requires a response body. A replay requires
the expected HTTPS origin, status 401 and the exact
`WWW-Authenticate: Bearer error="invalid_token"` header; GET/POST additionally require the
`invalid_token` error envelope. These signals mean ingress rejected the request before the
business handler ran.

## Ownership and lifecycle

`NovaAuthFacade` publishes configuration and injects one owner into both consumers. NovaAuth
owns identity, issuance, storage and DeviceCheck. Its request decorator freezes method, path,
query and body, adds the bearer, and permits one conclusive-denial replay. A separately bounded
readmission handles a credential rejected before sending; the exchange still makes at most
two actual sends and cannot replace its original client binding. Auth never replays an
arbitrary domain closure. The caller's `beforeSend` guard runs before every send, including replay.

Bittensor retains typed error mapping and flow-owned retry/presentation. Analytics checks
consent and its epoch before every send, retains auth-failed batches silently, and relies on
normal later flushes. Auth schedules no retry or UI. A fresh hit in the app's
`BittensorApiResponseCache` is served above admission; otherwise admission precedes the fetch and
authorization precedes network access. NovaAuth has no HTTP cache; the app store reuses fresh
bodies for their `max-age` and keeps expired ones only as stale display seeds.
Store hits never extend bearer lifetime.

**Local lifecycle policy:** host `activate(origin:)` authorizes later demand, including
consented Analytics, after accepted origin adoption or legacy-reset repair. Activation itself
generates no key and sends no authentication. This deliberately differs from the external
contract's requirement that a removed identity be recreated by a new user-driven operation.
Consent, erasure and wallet changes do not reset shared auth identity; the package exposes no
explicit reset API.

## Simplification and retained safeguards

Removed request intent, user-action gates, persisted recovery ladders, recreation quotas,
business-family cooldowns, the consent recovery helper/scheduler, routine diagnostic event
taxonomy and redundant bootstrap-factory injection. The owner constructs that factory from
HTTP and clock dependencies. Diagnostics retain asynchronous, redacted failure reporting.

The remaining mechanisms protect specific boundaries:

- Single-flight issuance coalesces concurrent demand and attempts at most one new key per
  flight. Retirement fails that flight; only a later independent demand can replace it.
- Typed bootstrap steps identify current work; irreversible commitment remains sticky across
  steps. Native per-key leases prevent overlapping proofs. After invocation, only the actual
  DeviceCheck callback releases the lease, even after cancellation or timeout. Both native and
  bootstrap HTTP watchdogs remain; a missing callback keeps the key busy until process restart.
- Lost registration retains UUID, key and original pending start. Exact `401 unknown_client`
  at challenge or issuance preserves pending state within the same-boot 120-second window;
  confirmed absence outside it retires and fails. Challenge success alone does not confirm
  pending registration. Transport/503 failures do not prove absence. Ordinary `401 invalid_proof`
  and `403 binding_not_allowed` preserve the binding, avoiding rotation around policy denial.
- Short issuance backoff and persisted pending-probe backoff remain. Only business 429 and
  explicit `503 attestation_unavailable` constrain the shared origin. Other business failures
  reach the caller; generic success does not clear that deadline.

## Storage compatibility

Installation storage keeps its existing key/version and validates surviving security fields.
Removed optional policy fields are ignored and disappear on the next existing write. Legacy
`policyRefused` with a key resumes probing that binding. Version-1 bearers require fresh issuance
while preserving valid installation identity; version 2 stores the flow-free bearer atomically
in the host-namespaced Keychain service, before delivery.

Context fences advance before storage I/O. Failed saves preserve staged repair and token-removal
debt, blocking admission until activation repairs them. Conditional token deletion protects newer
credentials. Continuous-clock expiry remains boot-bound. Ordinary issuance/origin cooldowns
remain memory-only across restart.

## Review map

| Start here | Review focus |
| --- | --- |
| [Framing](Sources/NovaAuth/Wire/NovaAuthFraming.swift) | Flow-free issuance preimage |
| [Request decorator](Sources/NovaAuth/Authorization/NovaAuthAuthorizedOperationFactory.swift) | Frozen replay, caller guard, send bounds |
| [Owner](Sources/NovaAuth/Lifecycle/NovaAuth.swift) and [registration](Sources/NovaAuth/Lifecycle/NovaAuthRegistrationService.swift) | Activation, fencing, retirement and pending absence |
| [Token provider](Sources/NovaAuth/Lifecycle/NovaAuthTokenProvider.swift) | Single flight, same-binding renewal, persistence before delivery |
| [Analytics uploader](../NovaAnalytics/Sources/NovaAnalytics/AnalyticsUploader.swift) | Consent and silent failed-batch retention |
| [Bittensor factory](../../novawallet/Common/Network/Bittensor/BittensorApiOperationFactory.swift) | Admission, routes and unavailable root yield |

## Verification and limits

The functional snapshot passed 14 NovaAuth tests, 43 NovaAnalytics tests and 121 selected app
tests, with zero failures, including app/test-target compilation. Existing cases were adapted;
the two helper-only Analytics tests were removed, without an expanded coverage matrix.
Subsequent removal of 18 comments across 14 files preserved all 24,397 Swift tokens and syntax;
tests were not rerun for that comment-only change.

Physical-device App Attest, signed Keychain sharing, protected-data transitions and reboot
behavior remain unverified. Settings cached read-back cannot prove disk durability. These checks
do not establish backend deployment or the external PR's current state.
