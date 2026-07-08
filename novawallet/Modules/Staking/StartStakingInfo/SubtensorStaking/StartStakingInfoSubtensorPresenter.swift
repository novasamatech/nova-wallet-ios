import Foundation
import BigInt
import Foundation_iOS

/// v1 Subtensor presenter for Nova's generic `StartStakingInfoViewController`.
///
/// The base presenter's `provideViewModel(state:)` requires a populated
/// `StartStakingStateProtocol` with min stake, reward time, unstake time,
/// reward delay, and max APY to render. Subtensor v1 does not yet query
/// real on-chain values for min stake, reward time, unstake time, or reward
/// delay (design spec §13 open questions + no indexer backend), so those
/// fields are seeded with hardcoded v1 values from research-tao.md.
///
/// TODO(wiki): The "Find out more" link on this screen currently falls back
/// to `applicationConfig.websiteURL` (i.e. https://novawallet.io) because
/// Bittensor's chain entry in nova-utils does not set `additional.stakingWiki`.
/// When the Nova Wiki page for Bittensor staking is published, add
/// `"stakingWiki": "<url>"` to the Bittensor chain in `chains.json` and
/// `chains_dev.json` (and `chains_dev_subtensor.json` for local dev). No iOS
/// code change is needed — `StartStakingInfoBasePresenter` already prefers
/// `chain.stakingWiki` over the website fallback.
///
/// The max-APR value — unlike the others — is a user-visible headline
/// number ("Earn up to X%") that benefits from being real as soon as the
/// network data source can supply it. [TEMP-TAOSTATS] Phase B therefore
/// fires the view model twice: once synchronously on `setup()` with the
/// hardcoded fallback so the page renders instantly, and a second time
/// after the TaoStats data source returns with the true cross-validator
/// peak APR. When Nova's indexer ships, only the injected data source
/// changes — the presenter wiring stays.
final class StartStakingInfoSubtensorPresenter: StartStakingInfoBasePresenter {
    /// Phase A hardcoded fallback used before the data source fetch lands
    /// and if the fetch fails or returns no validators.
    static let fallbackMaxApy: Decimal = 0.18

    /// Number of top-stake validators sampled when computing the "Earn
    /// up to X%" headline. TaoStats's 30-day APR column is calculated
    /// per-hotkey and micro-stake validators with a single recent reward
    /// can appear with APRs in the hundreds of percent. Restricting the
    /// sample to the top-N by total stake mirrors the validator picker's
    /// default sort and keeps the headline anchored on realistic returns
    /// from serious operators.
    static let headlineSampleSize = 20

    private let dataSource: SubtensorValidatorDataSourceProtocol

    init(
        chainAsset: ChainAsset,
        interactor: StartStakingInfoInteractorInputProtocol,
        wireframe: StartStakingInfoWireframeProtocol,
        startStakingViewModelFactory: StartStakingViewModelFactoryProtocol,
        balanceDerivationFactory: StakingTypeBalanceFactoryProtocol,
        localizationManager: LocalizationManagerProtocol,
        applicationConfig: ApplicationConfigProtocol,
        dataSource: SubtensorValidatorDataSourceProtocol,
        accountManagementFilter: AccountManagementFilterProtocol = AccountManagementFilter(),
        logger: LoggerProtocol
    ) {
        self.dataSource = dataSource
        super.init(
            chainAsset: chainAsset,
            interactor: interactor,
            wireframe: wireframe,
            startStakingViewModelFactory: startStakingViewModelFactory,
            balanceDerivationFactory: balanceDerivationFactory,
            localizationManager: localizationManager,
            applicationConfig: applicationConfig,
            accountManagementFilter: accountManagementFilter,
            logger: logger
        )
    }

    override func setup() {
        super.setup()
        view?.didReceive(viewModel: .loading)

        // Instant render with the hardcoded fallback so the screen is not
        // stuck on a spinner while the network fetch is in flight.
        var state = Self.makeV1State(chainAsset: chainAsset)
        provideViewModel(state: state)

        // [TEMP-TAOSTATS] Replace the hardcoded headline with the real
        // peak APR among top-stake validators as soon as the data source
        // returns.
        Task { [weak self, dataSource] in
            do {
                let rows = try await dataSource.fetchValidatorData(
                    netuid: SubtensorStakingConstants.rootNetuid
                )
                let topByStake = rows
                    .sorted { $0.totalStake > $1.totalStake }
                    .prefix(Self.headlineSampleSize)
                let maxApr = topByStake
                    .compactMap(\.apr)
                    .max()
                guard let self, let maxApr, maxApr > 0 else { return }
                let decimal = Decimal(maxApr)
                await MainActor.run {
                    state.maxApy = decimal
                    self.provideViewModel(state: state)
                }
            } catch {
                // Soft-fail: stick with the hardcoded fallback already rendered.
                self?.logger.error("TaoStats max-APR fetch failed: \(error)")
            }
        }
    }

    private static func makeV1State(chainAsset: ChainAsset) -> State {
        State(chainAsset: chainAsset)
    }

    /// Suppress the base "You already have staking in %@" alert. The base
    /// implementation fires it whenever stake state flips on while the
    /// StartStakingInfo screen is alive — and Subtensor's `SharedOperation`
    /// is not plumbed through the stake confirm flow to call `markSent()`,
    /// so `isComposing` stays `true` forever and the alert misfires every
    /// time the user's own stake confirm tx lands. For Bittensor (single
    /// coldkey, signed locally) there is no realistic "external party
    /// staked for you" case to warn about — just dismiss the modal so the
    /// user lands back on the multistaking dashboard with the new stake.
    override func didReceiveStakingEnabled() {
        wireframe.complete(from: view)
    }
}

extension StartStakingInfoSubtensorPresenter {
    /// Hardcoded v1 Subtensor staking state. Values verified against
    /// finney mainnet (queried 2026-04-30) — research-tao.md's "0.1 TAO
    /// min stake" was stale; on-chain `NominatorMinRequiredStake` is
    /// 10_000_000 RAO = 0.01 TAO.
    ///
    /// - Min stake: 0.01 TAO (10_000_000 RAO) — verified live.
    /// - Reward time: ~1.2 hours — one Bittensor tempo (360 blocks × ~12s).
    /// - Unstake time: 0 — `removeStakeLimit` is instant, no unbonding queue.
    /// - Reward delay: 0 — rewards accrue from the next tempo after stake.
    /// - Rewards destination: `.stake` — Bittensor auto-restakes emissions
    ///   into the same hotkey position at each tempo (no manual claim).
    /// - Max APY: 18% fallback. [TEMP-TAOSTATS] Overwritten with the real
    ///   cross-validator peak APR when the TaoStats fetch lands.
    struct State: StartStakingStateProtocol {
        let chainAsset: ChainAsset

        var minStake: BigUInt? { 10_000_000 }
        var rewardTime: TimeInterval? { 4320 }
        var unstakingTime: TimeInterval? { 0 }
        var rewardDelay: TimeInterval? { 0 }
        var maxApy: Decimal? = StartStakingInfoSubtensorPresenter.fallbackMaxApy
        var rewardsAutoPayoutThresholdAmount: BigUInt? { nil }
        var govThresholdAmount: BigUInt? { nil }
        var shouldHaveGovInfo: Bool { false }
        var rewardsDestination: DefaultStakingRewardDestination { .stake }
    }
}
