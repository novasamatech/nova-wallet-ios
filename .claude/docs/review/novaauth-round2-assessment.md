# NovaAuth round-2 assessment

12 October 2026. Client baseline: `feature/nova-auth` at `14567daae`.

Inputs: Claude's `REVIEW2.md` in the `advrev2` scratchpad and
`.claude/docs/review/novaauth-round2-fix-plan.md`. This is an assessment, not an implementation
instruction. The application code and both input documents were left unchanged.

## Opinion

The review identifies real defects we missed: completed business requests retain their operations,
and registration refusal is not distinguished adequately from recoverable key loss. The plan is a
useful starting point, but T2–T5 need revision before implementation. Even taking D1–D3 as the policy
recorded in that document, the proposed counters and reboot behavior do not implement that policy
reliably.

The single NovaAuth owner and shared profile-3 bearer remain the right client structure. None of
these findings justifies profile 2, separate service tokens, or moving authentication back into
consumers. Server changes to the two existing POST endpoints remain separately owned.

## Confirmed defects

### 1. Business-exchange retain cycle — fix first

L3-1 is correct. The cancellation object retains its action, that action retains the HTTP wrapper,
the wrapper retains the operation, and the operation's retained `beforeSend` closure retains the
exchange. The exchange owns the cancellation object. Its completion also retains the outer waiter.
Clearing the target's `completionBlock` does not break the other cycle.

Sources: [cancellation ownership](/Users/svojs/Documents/workspace/nova-wallet-ios/Packages/NovaAuth/Sources/NovaAuth/Lifecycle/NovaAuthWaiterOperation.swift:23),
[exchange completion](/Users/svojs/Documents/workspace/nova-wallet-ios/Packages/NovaAuth/Sources/NovaAuth/Authorization/NovaAuthAuthorizedOperationFactory.swift:132),
[transport closure](/Users/svojs/Documents/workspace/nova-wallet-ios/Packages/NovaAuth/Sources/NovaAuth/HTTP/NovaAuthHTTPTransport.swift:46).

I independently compiled a focused probe using copies of the current factory and cancellation/
waiter source, the real Operation-iOS base classes, and a fake HTTP boundary with the same retained
closure ownership. Both completed GET and POST retained the child and outer operation, including
a 1 MiB response. Applying T1's `release()` only to the temporary copies made both operations
deallocate in both scenarios. This is a lifetime probe, not a device or real-network test.

T1 is sound: release the cancellation action on terminal completion, preserving atomic enqueue
and cancellation. Add coverage through issuer and reader, including failure and replay. A weak
wrapper alone is insufficient because the queue retains operations, not that wrapper.

Probe: [reproduction script](/private/tmp/novaauth_round2_probe.py).

### 2. Persistent registration refusals cause repeated automatic key creation

CC-1 and L1-1 describe one issue. Most non-429 registration 4xx retire the identity; a later
background demand can recreate it after a fixed 60 seconds. Continued refusal can therefore keep
creating keys. This is demand-driven, not a self-scheduling minute timer; analytics' own backoff
reduces its actual frequency. That qualification does not remove the operational risk.

Distinguish a conclusively refused registration from genuine key loss. I support preventing
background replacement after conclusive refusal. The exact four delay values and recreation
budget are product/load policy; they are not prescribed by Apple. The previous fixed-delay choice
does not excuse applying automatic recovery to the wrong failure classes.

Sources: [retirement and delay](/Users/svojs/Documents/workspace/nova-wallet-ios/Packages/NovaAuth/Sources/NovaAuth/Lifecycle/NovaAuth.swift:150),
[replacement admission](/Users/svojs/Documents/workspace/nova-wallet-ios/Packages/NovaAuth/Sources/NovaAuth/Lifecycle/NovaAuthRegistrationService.swift:5).

### 3. `app_not_allowed` leaves a registration pending that cannot succeed

CC-3, L1-3 and L2-1 overlap. The client persists pending before sending registration, then excludes
this refusal from retirement. The next user action probes a binding that was never created;
replacement can happen later on background demand. The backend snapshot confirms this error is
emitted at registration, not at token issuance. Existing tests putting it at token issuance miss
the real sequence.

T3 should retire the refused identity immediately and permit a replacement directly on a later
eligible user action, without the unknown-client probes. Its acceptance criterion needs clearer
action counting: initial registration is key 1; the next eligible user action can create key 2.

Source: [registration failure handling](/Users/svojs/Documents/workspace/nova-wallet-ios/Packages/NovaAuth/Sources/NovaAuth/Lifecycle/NovaAuthRegistrationService.swift:199).

## Changes needed in the proposed plan

### T2–T5: define what is counted before adding the ladder

The existing code reserves recovery delay both when retiring and when beginning replacement.
Replacing that function with an incrementing ladder produces this sequence without jitter:

| Event | Stored failures | New delay |
|---|---:|---:|
| Original key fails and is retired | 1 | 60 seconds |
| First background replacement begins | 2 | 600 seconds |
| Replacement fails and is retired | 3 | 3,600 seconds |
| Next background replacement is considered | 3 | Rejected by `failures < 2` |

That charges one recovery twice and allows only one background recreation. An assertion of
“at most two” would still pass, even if zero were permitted; test the intended exact sequence.

T3's binding-policy refusals and T5's invalid proofs also feed this counter. They can exhaust the
alleged key-creation budget before any replacement key exists. Reusing a cooldown *type* is fine;
reusing one field for unrelated retry policies and a key-creation allowance is not justified.

Define one counted event, separate the recreation allowance from other refusal delays, and store
enough information to reconstruct the applicable policy. If crash-safe reservation is necessary,
do not charge again when its outcome arrives. The claim “no new stored fields needed” is premature.

### T2: reboot re-anchoring is underspecified and can substantially delay recovery

The current cooldown chooses a step before incrementing its count. Reconstructing a deadline with
`step(failures)` therefore advances a tier unless the plan explicitly defines a one-based mapping.
It must also preserve the different 600-second, 3,600-second and 86,400-second caps. A generic
re-anchor cannot infer those reliably from the proposed shared record.

Restarting the entire tier after a reboot means a user can receive a fresh 24-hour wait even if
the old wait expired days ago. The current boot marker is exact `kern.boottime`; calendar clock
steps can change it too. Leaving that heuristic unchanged while restarting long delays increases
its availability cost. Apple's [XNU calendar implementation](https://github.com/apple-oss-distributions/xnu/blob/main/osfmk/kern/clock.c)
supports this distinction between continuous elapsed time and the calendar-derived boot marker.

Specify this tradeoff explicitly, preserve usable-bearer-first behavior, and account for existing
stored counts: those represented fixed-delay reservations, not escalation tiers. Decoding an old
record is not sufficient to prove its new interpretation is correct. Also define whether the
maximum includes the proposed 10% jitter.

Source: [current cooldown semantics](/Users/svojs/Documents/workspace/nova-wallet-ios/Packages/NovaAuth/Sources/NovaAuth/Lifecycle/NovaAuthCooldown.swift:7).

### T4: retain the conservative Apple handling, but describe its limits accurately

I do not endorse REVIEW2's alternative of fetching a fresh challenge/hash and retrying the same
key as an established fix. Apple's [attestKey guidance](https://developer.apple.com/documentation/devicecheck/dcappattestservice/attestkey%28_%3Aclientdatahash%3Acompletionhandler%3A%29?language=objc)
specifies retaining both key and hash after `serverUnavailable`; it does not resolve our backend's
expired-challenge case. The plan's D2 is a conservative policy choice that avoids relying on
unverified behavior. Its cost is that an Apple outage can leave analytics waiting for user action.

A pre-call margin is useful, but “20 seconds covers attestKey plus register” is unsupported. The
local Apple call timeout is 100 seconds. A call started within the proposed budget can still
finish too late. Registration expiry is checked when the server claims the request, not when its
whole response returns. Keep the post-call check, retain the nonnegative-age check, call 20 seconds
a chosen minimum remaining budget, and test the actual boundary at age 40 seconds.

T2 also says every non-429 registration 4xx retires, while T3 excludes `invalid_proof`. Settle that
rule once. A timeout or expired attempt is not a conclusive server refusal, even if it shares the
same user-only recovery policy; reason and policy should remain distinguishable in diagnostics.

### T5: reasonable hardening, not proof replay

Repeated `invalid_proof` can cause unnecessary fresh challenge/assertion work. A longer persisted
delay is reasonable, preserving the key and assertion counter. But the client does not resend the
same proof: later attempts create fresh challenges and assertions. The contract's prohibition on
retrying a proof does not itself require a one-hour delay for all subsequent fresh attempts.
Keep this delay separate from key-recreation accounting.

### Missing item: a new consent action can disappear before admission

D3 accepts the absence of an automatic recovery trigger when consent was already enabled. That
does not settle L5-2: a user actually turns consent on, configuration loading fails, and the
completion silently returns. An admission rejected before the gate during cooldown is also
discarded. Later background uploads cannot consume that lost user action.

The plan should explicitly fix or accept this separate case. A fix should retain a bounded pending
action or expose an explicit retry, respect consent withdrawal, and not transfer an old action
silently to a later reset/origin generation. Relabeling every upload as user-initiated is wrong.

Source: [consent recovery completion](/Users/svojs/Documents/workspace/nova-wallet-ios/Packages/NovaAnalytics/Sources/NovaAnalytics/AnalyticsConsentAuthRecovery.swift:25).

## Remaining plan items and review findings

| Item | Assessment |
|---|---|
| T6: `attestation_failed` | A conclusive refusal should not look like a transient outage. Agree with correcting presentation. |
| T6: `client_already_registered` | This means binding/key ownership conflict, not necessarily a defective device or failed platform attestation. Suppressing blind retry may be right, but do not describe it as a conclusive platform verdict. The current `isDeviceBound` flag conflates retry policy and presentation. |
| T6: `insufficient_scope` | Agree: this is an authorization/configuration mismatch, not a request the user can repair by repeating it. It does not justify another token for another consumer. |
| T6: uncoded 500 | Traefik ForwardAuth can return 500 when its auth call fails; sharing its cooldown is a defensible topology-specific heuristic, not a universal HTTP guarantee. Keep 502/504 domain-local. The ambiguity of uncoded 503 remains; one unhealthy domain can also produce it. |
| T7: privacy manifest/container URL | Confirmed dead declarations/dependency. Remove them and update host documentation. No remaining file-timestamp API use was found in the package. This is cleanup, not evidence that it caused the device failure. |
| T7: legacy untagged bearer | Conditional deletion cannot match a bearer lacking the fingerprint. The proposed main-writer-only fallback is reasonable under the sole-writer/gate invariant. Never put unconditional fallback deletion in the reader. This is lower priority for an unshipped branch. |
| T7: diagnostics | Add the fixed retirement reason. The review also points out missing cooldown scope and storage-failure entry diagnostics; the plan covers only part of that feedback. |
| T7: busy check | Useful before spending another token challenge. Reject the review's optional timed lease release: suppressing a late callback does not establish that the underlying Apple call ended. The plan appropriately does not propose that release. |
| L3-2: deletion failure | Confirmed: a throwing deletion skips the repeated-denial cooldown. Move that cooldown before deletion. Making all deletion failures best-effort is a separate decision; the rejection set is process-local and token installation also depends on Keychain availability. The plan currently omits this finding. |
| T8: POST replay | Document that `invalid_token` must be rejected before either POST reaches its business handler. Track this with the separately owned server migration; keep the existing paths and the same profile-3 bearer. |
| Downgrade compatibility | Keeping unsupported downgrade to old branch builds out of scope is reasonable for unshipped state. |
| In-memory issuance Retry-After | A real relaunch limitation, already lower priority. Document it if intentionally retained; it does not mean the server accepts an early issuance. |

Traefik evidence: [confirmed ForwardAuth failure report](https://github.com/traefik/traefik/issues/12234).
Privacy category reference: [Apple required-reason API list](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitype).

## T9 needs stronger targeted validation, not indiscriminate test pruning

Keep lean tests focused on meaningful behavior. Separate commits and comment style are workflow
preferences, not evidence of a runtime defect. They should not decide whether a regression remains
covered. Reverting one fix may legitimately fail several related tests; “only its test fails” is
too rigid.

Three corrections are particularly important:

1. Preserve the intentional `404 unknown_client` negative fixture in
   [PendingEvidenceTests](/Users/svojs/Documents/workspace/nova-wallet-ios/Packages/NovaAuth/Tests/NovaAuthTests/Lifecycle/NovaAuthPendingEvidenceTests.swift:12).
   It verifies that the wrong status/code combination does not count as conclusive evidence.
   Correct only fixtures intended to model the server's real unknown-client response.
2. Add mixed-error/cap/reboot behavior tests if the ladder is implemented, plus a test preserving
   use of a still-valid bearer. These cover new policy interactions absent from T9's five additions.
3. Make the stale-cancellation ownership test deterministic. The review reports that its unsafe
   mutation passed 200 repetitions; the current test also visibly lacks a forced interleaving.
   This is a coverage gap, not evidence that the current atomic implementation is broken. Do not
   merely delete it and claim that guarantee remains tested.

## Research and limits

The assessment combines direct client inspection, an independent fresh Astra Extra High recovery
review, the focused compiled ownership probe, and primary-source checks. Backend cross-checks used
the available attestation source/contract snapshot; they do not establish today's live deployment.
Claude's reported revert-verification results are attributed to his review, not claimed as rerun.
No full app/package suite was rerun for this read-only assessment. No device authentication was
performed. No application code, review input, or plan was changed; nothing was committed or pushed.

Recommended order: fix the ownership leak and real registration-refusal path; revise the recovery
policy representation and tests; address lost consent actions and repeated-denial cooldown ordering;
then apply the agreed classification, diagnostics and documentation changes. Preserve the existing
working concurrency, generation fencing, storage repair and shared-bearer behavior.
