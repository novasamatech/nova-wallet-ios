# NovaAuth round-2 fix plan (v2)

12 October 2026 · `feature/nova-auth` @ `14567daae`.

**Inputs**
- The round-2 adversarial review of `df883652f`, `2790bfc3f`, `6186d114b` and `14567daae`.
- The owner's decisions D1–D3.
- ChatGPT's critique of v1 (`novaauth-round2-assessment.md`). v2 adopts all of its corrections.

**Already correct.** The round-2 review found these fixes correct and guarded by revert-verified tests, so this plan
leaves them alone: F04/F14, F06, F07, F08, F09, F10, F11, F15–F17, F20, the diagnostics redaction and the N01 grader.

**Method.** Take the tasks in order. Each task is one source commit. Tests go in separate commits (see T10).

## What changed from v1

- **The recovery state is redefined (T3).**
  - v1 reused one `failures` counter for three things: retry delays, binding-policy refusals and invalid proofs. It also
    charged that counter twice per recovery, in `retire()` and again in `prepareIdentity`.
  - v2 separates the retry delays from a key-recreation budget, and charges each event exactly once.
- **Reboot.** v1 re-anchored delays after a reboot. That could advance a tier, or impose a fresh 24 h wait long after
  the old one had expired. v2 keeps every delay boot-scoped, as today. The protection against minting keys comes from a
  persisted recreation budget that a reboot does not reset.
- **The Apple pre-call margin is a chosen minimum, not a guarantee (T5).** The 100 s local Apple timeout means a call can
  still finish late, so the post-call check stays authoritative.
- **New task T7:** a consent opt-in can be lost when the config load fails (D4: fix).
- **New task T8:** apply the repeated-denial cooldown before deleting the token (L3-2).
- **T10 keeps the intentional `404 unknown_client` inconclusive fixture.** It adds mixed-failure, cap, reboot and
  usable-bearer tests, and makes the cancellation ownership test deterministic.

## Owner decisions

| # | Decision | Status |
|---|---|---|
| D1 | Escalating recovery delay with a cap, and no background key recreation after a conclusive registration refusal | Approved 2026-10-12. The v2 refinement is also approved: delays are boot-scoped, and the cap is a persisted recreation budget. |
| D2 | An expired Apple-deferred attempt is retired, and a new key is created only on a user action. Inside the window, retry with the same key and hash. | Approved |
| D3 | Consent-on analytics installs that never open Bittensor stay stopped after an origin change or reset, and this is documented | Approved |
| D4 | A consent opt-in lost to a config-load failure or an active cooldown is fixed with a bounded pending re-arm (T7) | Approved 2026-10-12: fix |

## T1 — Break the retain cycle that leaks every business exchange

Finding L3-1, confirmed independently by ChatGPT's probe.

**Change**
- Add `func release()` to `NovaAuthCancellation` (`Lifecycle/NovaAuthWaiterOperation.swift`). It sets `action = nil`
  under the lock.
- `NovaAuthBusinessExchange.finish(_:)` calls it on terminal completion, before delivering the result. "Terminal"
  covers success, failure, a final denial and cancellation suppression.
- The atomic `enqueue` is unchanged.

**Done when**
- The issuer and the reader both release their child and outer operations after each of these: a completed GET, a
  completed POST, a failure, and an `invalid_token` replay.
- Release is checked with weak references after the queues drain.

## T2 — Retirement reasons and who may recreate (stops the key-minting loop)

Findings CC-1 and L1-1. This task alone removes the blocker, before any ladder exists.

**Retirement reasons.** `NovaAuthRetirementReason` gains:

| Reason | Set by | Kind |
|---|---|---|
| `.lostKey` | `invalidKey` from an assertion (includes device migration) | Device-side loss |
| `.interrupted` | `.appleInFlight` found on relaunch (`RegistrationService.swift:47-48`) | Device-side loss |
| `.registrationRefused` | A non-429 4xx at `/register`, including `app_not_allowed` and uncoded or edge 4xx. One rule: `invalid_proof` is included (the server never sends it for iOS registration). | Server refused |
| `.registrationAbandoned` | `attestKey` failure or timeout other than `serverUnavailable`; an expired attempt (T5); `unknown_client` after the 120 s window; an oversized attestation object | Outcome unknown or expired, not a server refusal |
| `.unrecoverableRegistration` | Legacy, decode only | Treated as `.registrationAbandoned` |
| `.policyRefused` | Legacy, decode only | Keeps its existing probe-the-binding path at `prepareIdentity:14-24` |

`.registrationRefused` and `.registrationAbandoned` share one recovery policy but stay distinct for diagnostics.

**Recovery policy in `prepareIdentity`**

| Reason | Who may recreate the identity |
|---|---|
| `.registrationRefused`, `.registrationAbandoned`, legacy `.unrecoverableRegistration` | `.userInitiated` only |
| `.lostKey`, `.interrupted` | Any intent, subject to T3's budget. Until T3 lands, keep today's behaviour. |

Remove the `reserveRecoveryDelay()` call inside `prepareIdentity` (`RegistrationService.swift:26`). Only a retirement
charges a delay. Starting a replacement does not.

**Done when.** A persistent `401 attestation_failed` at `/register`, followed by any number of background demands and
relaunches, creates exactly one key. Each later `.userInitiated` action after the delay creates exactly one more.

## T3 — Recovery state: separate delays from the recreation budget (D1)

### State

`NovaAuthInstallationState` gains one Optional field, `recovery: NovaAuthRecoveryState?`, decoded with
`decodeIfPresent`:

```swift
struct NovaAuthRecoveryState: Codable, Equatable {
    var recreationDelay: NovaAuthCooldown?   // charged once per retirement
    var policyRetryDelay: NovaAuthCooldown?  // binding_not_allowed
    var proofRetryDelay: NovaAuthCooldown?   // invalid_proof at /tokens
    var backgroundRecreations: Int           // keys minted by non-userInitiated demands since the last bearer
}
```

- **Legacy.** The `recoveryCooldown` written by `df883652f` exists on dev and QA devices only. On decode, keep its
  deadline as `recreationDelay` with `failures = 0`. Its old count recorded fixed-delay reservations, not tiers.
- **Carry-through.** Every state rebuild carries `recovery` through: `setIdentity`, `persist` and storage repair.
  `replaceContext` drops it, because a generation change starts fresh.
- **Clearing.** `install()` clears everything: all three delays and `backgroundRecreations = 0`.

### Ladder

Add `mutating func failLadder(now:random:caps:)` to `NovaAuthCooldown`.

| Rule | Value |
|---|---|
| Base steps | 60 s, 600 s, 3,600 s, 86,400 s |
| Step index | `failures` BEFORE the increment: 0 → 60 s, 1 → 600 s, … |
| Jitter | `step × (1 + 0.1·random)`. Caps apply to the base step, before jitter. |
| Order | Then `failures += 1` |

Caps per delay:

| Delay | Cap |
|---|---|
| `recreationDelay` | 86,400 s |
| `policyRetryDelay` | 600 s |
| `proofRetryDelay` | 3,600 s |

### Charging (exactly once per event)

| Event | Charge |
|---|---|
| A retirement | `recreationDelay.failLadder` |
| `binding_not_allowed` | `policyRetryDelay.failLadder` |
| `invalid_proof` at `/tokens` | `proofRetryDelay.failLadder` |
| A non-`userInitiated` demand starts recreating an identity | `backgroundRecreations += 1`, persisted before `createKey` (crash-safe), never charged again when the outcome arrives |

### Budget

- `.lostKey` and `.interrupted` may recreate on a non-`userInitiated` demand only while `backgroundRecreations < 2`.
  After that they need `.userInitiated`.
- `.userInitiated` never consumes the budget.

### Reboot

- Every delay stays boot-scoped with the exact `kern.boottime` comparison (F19 unchanged), so a reboot ends the current
  wait.
- `backgroundRecreations` is a plain count, so a reboot never resets it.
- Document this trade-off. Mass key minting is bounded by the budget, not by wall time.

### Order in `demand`, unchanged in spirit

1. A usable bearer is returned first.
2. Then `originCooldown` and `issuanceCooldown`.
3. Then the `recovery` delays that apply to the current state:
   - `recreationDelay` only when the identity is retired;
   - `policyRetryDelay` only after `binding_not_allowed`;
   - `proofRetryDelay` only after `invalid_proof`.
4. Then the pending cooldown.

### Done when

- Exact sequences pass:
  - lost key, then background recreations number exactly 2, then the third needs a user action;
  - the delays follow exactly 60 s → 600 s → 3,600 s for consecutive failed recreations.
- Mixed failures: `binding_not_allowed` and `invalid_proof` never change `backgroundRecreations` or `recreationDelay`.
- Reboot ends the delay but keeps the budget.
- A still-usable bearer is served during every delay.

## T4 — `app_not_allowed` at `/register` and `binding_not_allowed`

Findings L1-3, CC-3 and L1-2.

**`app_not_allowed` at `/register`**
- `handleRegistrationFailure` (`RegistrationService.swift:140-146`) retires `.registrationRefused` under the T2 rule.
  Remove the `app_not_allowed`/`binding_not_allowed` exclusion at `:143`. `binding_not_allowed` is never sent at
  `/register` (server `workflow.py:216-217, 551-552`).
- In `fail()` (`TokenProvider.swift:170-183`), stop the extra `reserveRecoveryDelay` and the `requiresUserAction`
  write for `app_not_allowed`. The retirement already covers both.

**`binding_not_allowed`** (at token-challenge and `/tokens`)
- Keep the identity and registration, as today.
- Charge `policyRetryDelay`.
- Any intent may retry once the delay expires, because no key is minted.

**Done when.** Counting from the first registration as key 1:
- `app_not_allowed` at `/register` leaves Apple keys at 1, and sends no token-challenge probe for that identity.
- Background demands never create key 2.
- The next eligible `.userInitiated` action creates key 2.

## T5 — Apple `serverUnavailable` deferral and pre-call budget (D2)

Findings CC-2 and L1-4.

Split `validateAttemptAge` (`RegistrationService.swift:131-138`) in two:

| Check | Rule | On failure |
|---|---|---|
| Pre-call | Same boot, `age ≥ 0`, and `age ≤ 40`, a chosen minimum of 20 s left on the 60 s challenge | Runs BEFORE `setRegistration(.appleInFlight)` and BEFORE Apple. Retire `.registrationAbandoned`, throw `userActionRequired`, never call Apple. |
| Post-call | Same boot, `age ≥ 0`, `age < 60` | Unchanged, still authoritative: the local Apple timeout is 100 s, so a call started inside the budget can finish too late. |

Within the budget, `.appleDeferred` keeps retrying with the same key and hash (Apple guidance). That path is
unchanged.

**Done when**
- An attempt aged exactly 40 s is attested.
- One aged 40.001 s never reaches Apple and retires.
- No background demand recreates afterwards (T2).
- `NovaAuthRegistrationRecoveryTests.swift:25-42` is rewritten to these expectations.

## T6 — `invalid_proof` at `/tokens`: longer persisted backoff (hardening)

Findings L2-2 and CC-8.

- The client already creates a fresh challenge and assertion each time; it never replays a proof. This task only cuts
  needless work.
- `fail()` charges `proofRetryDelay` (T3). It does not retire, so the key and its assertion counter are kept.
- Any intent may retry once the delay expires.
- Rewrite the test that pins the ~31 s cadence.

## T7 — A lost consent opt-in (D4: fix)

Finding L5-2. In `Packages/NovaAnalytics/Sources/NovaAnalytics/AnalyticsConsentAuthRecovery.swift:36-41`,
`try? target?.extractNoCancellableResultData()` silently drops the user's opt-in when the config or auth endpoint
fails to load. An admission that a cooldown rejects is dropped too.

**Fix shape**
- Keep one in-memory pending re-arm per opt-in event.
- Retry it when the auth endpoint next resolves, with a short bounded backoff, at most 3 attempts per launch.
- Discard it on consent withdrawal, on deactivation, and on any context or generation change. Never move it to a newer
  generation.
- Never relabel uploads as `.userInitiated`.

## T8 — Repeated-denial cooldown before deletion

Finding L3-2. In `NovaAuth.reject` and `NovaAuthReader.reject`, apply the `repeated` issuance cooldown BEFORE
`tokenStore.remove(ifMatching:)`, so a failed delete cannot skip it. Deletion stays throwing. The rejected set already
keeps the bearer from being handed out again.

## T9 — Error classification

Findings CC-6, L5-4 and CC-5.

**Bittensor grader** (`BittensorAuthorizedResponseGrader.swift`)

| Response | Maps to |
|---|---|
| Bootstrap `401 attestation_failed` | `.attestationRejected` (a conclusive platform verdict; no "Try again") |
| `409 client_already_registered` | A non-retryable, non-device-bound error. It is a binding or key-ownership conflict, not a platform verdict. |
| `401 invalid_challenge`, 503, transport | Unchanged: retryable |
| `403 insufficient_scope` in `grade()` | `.invalidRequest`, placed before the generic `case 401, 403` |

**NovaAuth** (`NovaAuthBusinessCooldowns.swift:29`)
- An uncoded 500 is a shared auth/edge signal. It is Traefik's ForwardAuth failure signature, a heuristic specific to
  this topology.
- Uncoded 502, 504 and 503, and every coded domain 5xx, stay per family.

## T10 — Cleanups

1. **Privacy manifest.** Remove the `FileTimestamp`/`C617.1` entry from `PrivacyInfo.xcprivacy` (CP-1). No
   file-timestamp API remains.
2. **Dead dependency.** Remove the unused `containerURL` and the App Group container requirement from
   `SharedContainerGroup.novaAuthStore`. Keep the keychain access group. Update the host docs (CP-2, L4-3).
3. **Untagged legacy bearer** (L4-2, main app only). In `NovaAuth.reject` and `usableToken`, when
   `remove(ifMatching:)` returns false and `tokenStore.load()` still equals the record, call `tokenStore.removeAll()`.
   This is safe under the sole-writer and `gate` invariant. Never add this fallback to the reader.
4. **Diagnostics** (L5-3).
   - Add the fixed retirement reason to `.identityRetired`.
   - Add the cooldown scope (shared, family, recreation, policy or proof) to cooldown events.
   - Add an event when storage enters the failed or dirty state.
5. **Busy-key check** (L1-5). Add `isBusy(keyID:)` to `NovaAuthAppAttestProtocol` and check it in `issue()` before a
   token challenge. Never release a lease on a timer: a suppressed late callback does not prove the Apple call ended.

## T11 — Documentation

1. **D3.** State plainly in `Packages/NovaAuth/README.md` and
   `.claude/docs/review/novaauth-fix-validation.md`:

   > After an origin change or explicit reset, an install with analytics consent on and no Bittensor use uploads
   > nothing. Uploads resume after a Bittensor user action or a consent off/on cycle.

2. **Recovery.** Replace the "persisted minimum 60-second recreation interval" wording (CP-3) with the T2/T3 model:
   - which reasons let any intent recreate, and which need a user action;
   - the ladders and their caps;
   - the background budget of 2;
   - delays are boot-scoped while the budget is not.
3. **Classification.** Document the T9 classification: which responses back off shared and which per family (CP-4).
4. **Contract item.** Track this next to the separately owned server migration (L3-3, F24): `invalid_token` must be
   rejected before either POST reaches its business handler, which permits the single replay. Keep the existing paths
   and the same bearer.
5. **Accepted limitation.** Document the in-memory issuance Retry-After (F12).
6. **Diagrams.** Regenerate `novaauth-client-diagrams.md` and `.html` together, and fix the anchor that points at a
   blank line (CP-6).

## T12 — Tests

**Rules (owner's lean-tests rule)**
- Tests go in their own commits, separate from the source commits, so they can be dropped.
- No comments in tests; one scenario per test; names carry the meaning.

**Keep:** the `404 unknown_client` entry in `NovaAuthPendingEvidenceTests.swift:12`. It is a deliberate inconclusive
fixture. Correct only fixtures meant to model the server's real `unknown_client`, which is 401.

**Rewrite** the tests that pin changed behaviour:
- the fixed 60 s recreation (`NovaAuthRecoveryPolicyTests.swift:27-41`);
- the post-expiry retirement (`NovaAuthRegistrationRecoveryTests.swift:25-42`);
- the `invalid_proof` cadence.

**Add**
- T1: the exchange deallocates (issuer and reader; GET, POST, failure, replay).
- T2: a persistent `/register` 401 gives exactly one key under background demand and relaunch, and one more per user
  action.
- T3:
  - the exact ladder sequence;
  - the background budget, exactly 2;
  - mixed failures do not consume the budget;
  - reboot ends the delay but keeps the budget;
  - a usable bearer is served during the delays.
- T4: `app_not_allowed` at `/register` gives no probes, no background key, and one key on the next user action.
- T5: the 40 s / 40.001 s boundary.
- T7: an opt-in survives one config failure and is discarded on withdrawal.
- Make the stale-cancellation ownership test deterministic with a forced interleaving, for example a gate inside the
  test double's `addOperations`, instead of repetition.

**Gates.** Revert each fix hunk and confirm its intended test fails. Other failures are acceptable only if explained.

**Run before declaring done**
- the full NovaAuth package suite;
- the NovaAnalytics suite;
- `BittensorAuthorizedTransportTests` and the Subtensor flow tests.

## Out of scope

- F01 server work (owned by another developer).
- F19 boot-ID tolerance.
- Q4 and Q5.
- Deleting the reader.
- Downgrade compatibility with pre-fix branch builds (L4-1).
- The fresh-challenge, same-key retry from REVIEW2 (not adopted; D2 is the policy).
