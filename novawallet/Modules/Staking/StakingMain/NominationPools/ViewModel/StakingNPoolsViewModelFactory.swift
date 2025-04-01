import Foundation
import Foundation_iOS
import BigInt

struct StakingNPoolsViewModelParams {
    let poolMember: NominationPools.PoolMember?
    let bondedPool: NominationPools.BondedPool?
    let subPools: NominationPools.SubPools?
    let poolLedger: StakingLedger?
    let poolNomination: Nomination?
    let activePools: Set<NominationPools.PoolId>?
    let activeEra: ActiveEraInfo?
    let eraCountdown: EraCountdownDisplayProtocol?
    let totalRewards: TotalRewardItem?
    let totalRewardsFilter: StakingRewardFiltersPeriod?
    let claimableRewards: BigUInt?
}

protocol StakingNPoolsViewModelFactoryProtocol {
    func createState(
        for params: StakingNPoolsViewModelParams,
        chainAsset: ChainAsset,
        price: PriceData?
    ) -> StakingViewState
}

final class StakingNPoolsViewModelFactory {
    let balanceViewModelFactory: BalanceViewModelFactoryProtocol

    private let calendar = Calendar.current

    init(balanceViewModelFactory: BalanceViewModelFactoryProtocol) {
        self.balanceViewModelFactory = balanceViewModelFactory
    }

    private func createStakeViewModel(
        for params: StakingNPoolsViewModelParams,
        chainAsset: ChainAsset,
        price: PriceData?
    ) -> LocalizableResource<BalanceViewModelProtocol>? {
        guard
            let poolMember = params.poolMember,
            let poolLedger = params.poolLedger,
            let bondedPool = params.bondedPool else {
            return nil
        }

        let amount = NominationPools.pointsToBalance(
            for: poolMember.points,
            totalPoints: bondedPool.points,
            poolBalance: poolLedger.active
        ).decimal(precision: chainAsset.asset.precision)

        return balanceViewModelFactory.balanceFromPrice(amount, priceData: price)
    }

    private func createNominationStatus(for params: StakingNPoolsViewModelParams) -> NominationViewStatus {
        guard let activePools = params.activePools, let poolMember = params.poolMember else {
            return .undefined
        }

        guard poolMember.points > 0 else {
            return .inactive
        }

        guard !activePools.contains(poolMember.poolId) else {
            return .active
        }

        guard let nomination = params.poolNomination else {
            return .inactive
        }

        let poolState = Multistaking.NominationPoolState(
            poolMember: poolMember,
            era: params.activeEra,
            ledger: params.poolLedger,
            nomination: nomination,
            bondedPool: params.bondedPool
        )

        guard let onchainState = Multistaking.DashboardItemOnchainState.from(nominationPoolState: poolState) else {
            return .inactive
        }

        switch onchainState {
        case .activeIndependent:
            // we should be here as pool currently still need to consult offchain storage for activity
            return .active
        case .active:
            // we previously found that pool id still not in active pools list and not waiting
            return .inactive
        case .bonded:
            return .inactive
        case .waiting:
            return .waiting(eraCountdown: params.eraCountdown, nominationEra: nomination.submittedIn)
        }
    }

    private func createNominationViewModel(
        for params: StakingNPoolsViewModelParams,
        status: NominationViewStatus,
        chainAsset: ChainAsset,
        price: PriceData?
    ) -> LocalizableResource<NominationViewModel> {
        let localizedStakeViewModel = createStakeViewModel(
            for: params,
            chainAsset: chainAsset,
            price: price
        )

        return LocalizableResource { locale in
            let stakeViewModel = localizedStakeViewModel?.value(for: locale)

            return .init(
                totalStakedAmount: stakeViewModel?.amount ?? "",
                totalStakedPrice: stakeViewModel?.price ?? "",
                status: status,
                hasPrice: chainAsset.asset.priceId != nil
            )
        }
    }

    private func createUnbondingViewModel(
        from params: StakingNPoolsViewModelParams,
        chainAsset: ChainAsset
    ) -> StakingUnbondingViewModel? {
        guard let poolMember = params.poolMember, let subPools = params.subPools else {
            return nil
        }

        let poolsByEra = subPools.getPoolsByEra()

        let viewModels = poolMember
            .unbondingEras
            .sorted(by: { $0.key.value < $1.key.value })
            .map { unbondingKeyValue in
                let eraIndex = unbondingKeyValue.key.value
                let points = unbondingKeyValue.value.value

                let pool = poolsByEra[eraIndex] ?? subPools.noEra

                let unbondingAmount = NominationPools.pointsToBalance(
                    for: points,
                    totalPoints: pool.points,
                    poolBalance: pool.balance
                ).decimal(precision: chainAsset.asset.precision)

                let unbondingAmountString = balanceViewModelFactory.amountFromValue(unbondingAmount)

                return StakingUnbondingItemViewModel(
                    amount: unbondingAmountString,
                    unbondingEra: eraIndex
                )
            }

        return StakingUnbondingViewModel(
            eraCountdown: params.eraCountdown,
            items: viewModels,
            canCancelUnbonding: false
        )
    }

    private func createRewardsViewModel(
        from params: StakingNPoolsViewModelParams,
        chainAsset: ChainAsset,
        price: PriceData?
    ) -> LocalizableResource<StakingRewardViewModel> {
        let localizedTotalRewards = params.totalRewards.map { rewards in
            balanceViewModelFactory.balanceFromPrice(rewards.amount.decimalValue, priceData: price)
        }

        let localizedClaimableRewards = params.claimableRewards.map { rewards in
            balanceViewModelFactory.balanceFromPrice(
                rewards.decimal(precision: chainAsset.asset.precision),
                priceData: price
            )
        }

        let localizedFilter = params.totalRewardsFilter.map { $0.title(calendar: calendar) }

        let canClaimRewards = (params.claimableRewards ?? 0) > 0

        return LocalizableResource { locale in
            let totalRewards = localizedTotalRewards?.value(for: locale)
            let claimableReward = localizedClaimableRewards?.value(for: locale)
            let claimableRewardViewModel = claimableReward.map {
                StakingRewardViewModel.ClaimableRewards(balance: $0, canClaim: canClaimRewards)
            }

            let filter = localizedFilter?.value(for: locale)

            return StakingRewardViewModel(
                totalRewards: totalRewards.map { .loaded(value: $0) } ?? .loading,
                claimableRewards: claimableRewardViewModel.map { .loaded(value: $0) } ?? .loading,
                graphics: R.image.imageStakingTypePool(),
                filter: filter,
                hasPrice: chainAsset.asset.hasPrice
            )
        }
    }
}

extension StakingNPoolsViewModelFactory: StakingNPoolsViewModelFactoryProtocol {
    func createState(
        for params: StakingNPoolsViewModelParams,
        chainAsset: ChainAsset,
        price: PriceData?
    ) -> StakingViewState {
        let status = createNominationStatus(for: params)

        let nominationViewModel = createNominationViewModel(
            for: params,
            status: status,
            chainAsset: chainAsset,
            price: price
        )

        let unbondingViewModel = createUnbondingViewModel(
            from: params,
            chainAsset: chainAsset
        )

        let alerts = createStakingAlerts(for: params, status: status, chainAsset: chainAsset)

        let rewards = createRewardsViewModel(
            from: params,
            chainAsset: chainAsset,
            price: price
        )

        return .nominator(
            viewModel: nominationViewModel,
            alerts: alerts,
            reward: rewards,
            unbondings: unbondingViewModel,
            actions: [.stakeMore, .unstake]
        )
    }
}
