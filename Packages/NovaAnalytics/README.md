# NovaAnalytics

Consent-gated event collection and batched uploads. The app injects `AnalyticsAuthProvidingProtocol`
from its single shared NovaAuth facade. This package owns no App Attest keys, authentication
installation identity or bearer lifecycle. Every flush resolves the current endpoint and sends
immutable JSON to `/v1/analytics/events`.

The uploader passes an immediate send gate checking both consent and the batch's consent epoch.
NovaAuth repeats this gate before any authorized retry. Withdrawal cancels the upload waiter,
forgets the analytics install ID and schedules durable queue erasure; it does not reset shared
authentication. Existing fifty-event batches, scheduler and permanent payload rejection rules
remain in force. Transient/auth failures retain events silently for a later scheduled flush. Consent enablement
starts the normal session and tracking flow; there is no separate auth-recovery admission,
re-arm timer, prompt or notification. Host activation authorizes later demand-driven bootstrap,
including consented Analytics, without request-level intent. This local product lifecycle policy
replaces the profile-3 protocol's user-driven re-creation wording.

The backend must authorize the existing analytics POST with profile 3 before rollout; see
[the NovaAuth package](../NovaAuth/README.md). Run tests using the NovaAnalytics scheme and an
iOS simulator, not `swift test`.
