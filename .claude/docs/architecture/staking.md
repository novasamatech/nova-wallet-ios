# Staking

`novawallet/Modules/Staking/` is the largest feature area. It supports four staking mechanisms
behind one dashboard, so almost every change needs to answer "which staking type does this apply
to?".

## Staking Types

| Type                  | Chains                   | Shared state                    | Modules                       |
|-----------------------|--------------------------|---------------------------------|-------------------------------|
| Relaychain (direct)   | Polkadot, Kusama, …      | `RelaychainStakingSharedState`  | `StakingMain/Relaychain`, `SelectValidatorsFlow` |
| Nomination pools      | Relaychain + AssetHub    | `NPoolsStakingSharedState`      | `NominationPools/`            |
| Parachain (collators) | Moonbeam, Turing, …      | `ParachainStakingSharedState`   | `Parachain/`, `CollatorStaking` |
| Mythos                | Mythos                   | `MythosStakingSharedState`      | `Mythos/`                     |

`StakingType` and `Multistaking.ChainAssetOption` identify the option the user picked;
`RelayStkConsensusType` distinguishes Babe vs. Aura-based relaychains (affects era/time maths).

## Shared State

`StakingSharedStateFactory` builds a per-option bundle of long-lived services:

```swift
func createRelaychain(for stakingOption: Multistaking.ChainAssetOption) throws -> RelaychainStakingSharedStateProtocol
func createNominationPools(for chainAsset: ChainAsset, consensus: RelayStkConsensusType) throws -> NPoolsStakingSharedStateProtocol
func createParachain(for stakingOption: Multistaking.ChainAssetOption) throws -> ParachainStakingSharedStateProtocol
func createStartRelaychainStaking(for chainAsset: ChainAsset, consensus:selectedStakingType:) throws -> RelaychainStartStakingStateProtocol
func createMythosStaking(for stakingOption: Multistaking.ChainAssetOption) throws -> MythosStakingSharedStateProtocol
```

A relaychain shared state carries:

- `globalRemoteSubscriptionService` — era, validator count, min bond, etc.
- `accountRemoteSubscriptionService` — the user's ledger/nominations/controller
- `eraValidatorService` — the current era's validator set (`EraValidatorService`)
- `rewardCalculatorService` — APY engine (`RewardCalculatorService`)
- `timeModel` — `StakingTimeModel` (era duration, unstaking duration)
- `localSubscriptionFactory` — CoreData-backed staking providers
- `proxySubscriptionFactory` — proxy wallets for staking operations

The shared state is created **once per flow** in the entry ViewFactory and passed down. Screens call
`setup(for:)`/`throttle()` on it at flow boundaries, never per screen.

## Multistaking (Dashboard)

`Common/Services/Multistaking/` aggregates every staking position across all chains for the selected
wallet:

- `MultistakingSyncService` fans out to per-type update services (`RelaychainMultistakingUpdateService`,
  `PoolsMultistakingUpdateService`, `ParachainMultistakingUpdateService`,
  `MythosMultistakingUpdateService`, `OffchainMultistakingUpdateService`).
- Results are written into CoreData as `StakingDashboardItem`s and read by
  `Modules/Staking/Dashboard` through `StakingDashboardProviderFactory`.
- The off-chain part comes from the multistaking API (`GlobalConfig.multiStakingApiUrl`, Subquery).

When adding a new staking mechanism you must add: a shared state, an update service registered in
`MultistakingSyncServiceFactory`, a CoreData mapper (`StakingDashboard*Mapper`), and dashboard view
model support.

## Rewards & APY

`Modules/Staking/Services/RewardCalculatorService/`:

- `RelayChain/` — inflation-based APY. `PolkadotRewardEngine` /
  `PolkadotStakersRewardFactory` / `PolkadotStakersRewardFactory` derive the APY from the
  staking pallet's era reward allocation; `RewardCalculatorParamsServiceFactory` picks the engine per
  chain.
- Parachain and Mythos have their own engines under the same directory.
- `PayoutRewardsService` (`Common/Services/PayoutRewardsService/`) computes claimable payouts;
  `StakingRewardPayouts` / `StakingPayoutConfirmation` drive the UI.

APY maths is covered by unit tests (`novawalletTests/Modules/Staking/RewardCalculator/`) and
integration tests (`novawalletIntegrationTests/CalculatorServiceTests.swift`,
`NominationPoolsApyTests.swift`). **Any change to reward maths must update those tests.**

## Era & Time Model

`Modules/Staking/Operations/`:

- `StakingDuration/` — `BabeStakingDurationFactory`, `AuraStakingDurationFactory` produce era/epoch
  durations from runtime constants.
- `UnstakingDuration/` — `UnstakingDurationOperationFactory` computes the unbonding period, which
  differs between direct staking and pools and between consensus types.
- `EraCountdownOperationFactory` (`Common/Operation/`) drives "next era in …" countdowns.
- `BlockTimeEstimationService` (`Common/Substrate/BlockTime/`) estimates block time where it is not a
  constant.

Never hardcode era counts or block times — always derive them through these factories.

## Validator / Collator Selection

`SelectValidatorsFlow/` implements recommended + custom selection, filtering, and the confirm screen.
`PreferredValidatorsProvider` pulls the curated list from `ApplicationConfig.preferredValidatorsURL`.
`EraValidatorService` supplies the on-chain set; paged fetching lives in
`StakingValidatorExposureFacade` (see the integration test of the same name).

## Operations Catalogue

| Flow                     | Modules                                                              |
|--------------------------|----------------------------------------------------------------------|
| Start staking            | `StartStakingInfo`, `StartStakingConfirm`, `StakingSetupAmount`, `StakingType` |
| Bond more / unbond       | `StakingBondMore*`, `StakingUnbondSetup`, `StakingUnbondConfirm`, `StakingRedeem` |
| Rebond / rebag           | `StakingRebondSetup`, `StakingRebondConfirmation`, `StakingRebagConfirm` |
| Reward destination       | `StakingRewardDestinationSetup`, `StakingRewardDestConfirm`          |
| Payouts                  | `StakingRewardPayouts`, `StakingPayoutConfirmation`, `StakingRewardDetails` |
| Controller account       | `ControllerAccount`, `ControllerAccountConfirmation`                 |
| Proxy staking            | `StakingProxy`                                                       |
| Pools                    | `NominationPools/*`                                                  |
| Discovery                | `StakingMoreOptions`, `Dashboard`                                    |

Calls are built from `Common/Substrate/Calls/Staking`, `.../NominationPools`,
`.../ParachainStaking`, `.../MythosStaking`, `.../BagList`.

## Hard Rules

1. **Branch on staking type explicitly.** A change to "staking" that only touches the relaychain path
   is incomplete — check pools, parachain, and Mythos, or state why they are unaffected.
2. **Shared state is created once per flow.** Do not build services in a leaf screen's ViewFactory.
3. **Durations, eras, and APY come from runtime data**, never constants.
4. **Reward-maths changes require test updates** in both unit and integration suites.
5. **Dashboard items are derived data.** Write them only from the multistaking update services.
6. Presenters share behaviour through base classes/protocols per staking type
   (`RelaychainConsensusStateDepending`, base setup/confirm presenters) — extend those rather than
   copy-pasting a sibling flow.

## Related

- architecture/data-flow.md — staking local/remote subscriptions
- architecture/transactions.md — submitting staking extrinsics with the splitter
- code/testing.md — where staking tests and mocks live
