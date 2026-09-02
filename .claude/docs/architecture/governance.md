# Governance

`novawallet/Modules/Vote/Governance/`. The app supports both governance generations behind one UI.

## Governance Types

```swift
enum GovernanceType: String {
    case governanceV1 = "governance-v1"   // democracy + council
    case governanceV2 = "governance"      // OpenGov: referenda + convictionVoting + tracks
}
```

The chain declares which it supports through `ChainModel` options. The selected type is stored in
`GovernanceChainSettings` (`Common/Storage/GovernanceChainSettings.swift`) and drives which
subscription/operation factory pair is used:

| Type            | Subscription factory     | Pallets                                    |
|-----------------|--------------------------|--------------------------------------------|
| `governanceV1`  | `Gov1SubscriptionFactory`| `democracy`                                |
| `governanceV2`  | `Gov2SubscriptionFactory`| `referenda`, `convictionVoting`            |

Feature code must branch through the shared state's factories, not on the pallet name.
`GovernanceSharedState.supportsAbstainVoting` is an example of a capability flag derived from the
type — prefer adding such flags over scattering `if type == .governanceV2` checks.

## GovernanceSharedState

`Modules/Vote/Governance/Model/GovernanceSharedState.swift` is the flow-scoped service bundle:

| Member                             | Role                                                     |
|------------------------------------|----------------------------------------------------------|
| `observableState`                  | `ReferendumsObservableState` — current referenda snapshot |
| `settings`                         | `GovernanceChainSettings` — selected chain + gov type     |
| `subscriptionFactory`              | On-chain referenda/voting subscriptions                   |
| `referendumsOperationFactory`      | Fetch referenda, details, voters                          |
| `locksOperationFactory`            | Governance lock/unlock schedule                           |
| `blockTimeService`                 | Block time estimation for countdowns                      |
| `timepointThresholdService`        | Converts block/time thresholds for display                |
| `govMetadataLocalSubscriptionFactory` | Off-chain referendum metadata (titles, descriptions)   |
| `swipeGovService`                  | SwipeGov queue state                                      |

It is created once when entering the governance tab and reused by every child module. Services are
lazily created (`setupThresholdService()`) and held weakly where appropriate — do not force-create
them from a leaf screen.

## Local Models

On-chain and off-chain data are normalised into `*Local` models before reaching the UI:

`ReferendumLocal`, `ReferendumAccountVotingDistribution`, `ReferendumTracksVotingDistribution`,
`ReferendumAccountVoteLocal`, `ReferendumActionLocal`,
`ReferendumMetadataLocal`, `ReferendumDelegatingLocal`, `ReferendumVoterLocal`,
`GovernanceLockState`, `GovernanceUnlockSchedule`, `GovernanceDelegateState`.

This normalisation is what lets one set of screens serve both governance generations. **Add new data
to a `*Local` model**, not to a pallet-specific type that leaks into the Presenter.

`ReferendumDecidingFunctionProtocol` / `DemocracyDecidingFunctionProtocol` encapsulate the
approval/support curves so the UI can show "will pass / needs X% more" identically for both types.

## Data Sources

| Source                              | Provides                                            |
|-------------------------------------|-----------------------------------------------------|
| Chain storage subscriptions         | Referenda state, the user's votes, locks            |
| `GovernanceOffchainApi` (Subquery)  | Voters, delegate stats, historical votes            |
| `GovMetadataLocalSubscriptionFactory` | Titles/descriptions from the Polkassembly-style feed |
| `ApplicationConfig.governanceDAppsListURL` | Links to governance dApps                    |
| Polkassembly summary API            | AI summaries (key injected via Sourcery)            |

## Flows

| Area                | Modules                                                                |
|---------------------|------------------------------------------------------------------------|
| List & filtering    | `Referendums`, `ReferendumsFilters`, `ReferendumSearch`                 |
| Details             | `ReferendumDetails`, `ReferendumFullDetails`, `ReferendumVoters`        |
| Voting              | `ReferendumVote`, `ReferendumVoteSetup`, `ReferendumVoteConfirm`, `CommonVotes` |
| SwipeGov            | `SwipeGov` — batched voting with a swipe UI                            |
| Delegation          | `Delegations/` — delegate list, delegate info, tracks, revoke           |
| Track selection     | `GovernanceSelectTracks`                                               |
| Locks & unlock      | `GovernanceUnlock`, `GovernanceUnlockSetup`, `GovernanceUnlockConfirm`  |
| Remove votes        | `GovernanceRemoveVotesConfirm`                                         |
| Chain selection     | `GovernanceChainSelection`                                             |

Extrinsics are built by `Operation/Extrinsics/` factories behind
`GovernanceExtrinsicFactoryProtocol`, so a vote/delegation call is constructed the same way for both
governance types. Batched actions (SwipeGov, multi-track delegation, unlock across tracks) use
`ExtrinsicSplitter` — see architecture/transactions.md.

## Conviction & Locks

- `GovernanceBalanceConviction` / `GovernanceBalanceCalculator` compute the voting power and the
  amount available given existing locks.
- `GovernanceUnlockSchedule` determines what is claimable now vs. later; the unlock flow relies on it
  rather than re-deriving lock maths in the Presenter.
- Validation lives in `Validating/` and follows the `DataValidating` pattern.

## Notifications

`Modules/Notifications/GovernanceNotifications` and `GovernanceTracksSettings` configure which
referendum events push notifications are delivered for; the handling side is
`Common/PushHandling/Governance`.

## Hard Rules

1. **Never write pallet-specific types into the Presenter.** Convert to `*Local` models in the
   operation/subscription layer.
2. **Both governance types must keep working.** A change to voting/locks needs a Gov1 answer as well
   as Gov2, even if it is "not applicable".
3. **Take services from `GovernanceSharedState`**; don't build referenda factories per screen.
4. **Block-based deadlines go through the block time / timepoint threshold services** so countdowns
   stay correct on chains with irregular block times.
5. **Off-chain metadata is optional.** Referenda must render without titles/descriptions.

## Related

- architecture/transactions.md — building and splitting governance extrinsics
- architecture/data-flow.md — referenda subscriptions and metadata providers
