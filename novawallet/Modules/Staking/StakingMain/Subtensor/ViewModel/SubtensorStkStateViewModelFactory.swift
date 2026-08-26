import BigInt
import Foundation
import Foundation_iOS

protocol SubtensorStkStateViewModelFactoryProtocol {
    func createViewModel(from state: SubtensorStakingStateProtocol) -> StakingViewState

    func createPositionViewModels(
        for stakingState: Multistaking.SubtensorStakingState,
        commonData: SubtensorStakingCommonData,
        selectable: Bool
    ) -> [AccountDetailsPickerViewModel]

    func createNetworkInfoViewModel(
        from networkInfo: SubtensorNetworkInfo,
        chainAsset: ChainAsset,
        price: PriceData?,
        locale: Locale
    ) -> NetworkStakingInfoViewModel

    func hasAlphaPositions(in stakingState: Multistaking.SubtensorStakingState) -> Bool
}

final class SubtensorStkStateViewModelFactory {
    private var lastViewModel: StakingViewState = .undefined
    private(set) var priceAssetInfoFactory: PriceAssetInfoFactoryProtocol
    private let calendar = Calendar.current

    private lazy var displayAddressFactory = DisplayAddressViewModelFactory()

    init(priceAssetInfoFactory: PriceAssetInfoFactoryProtocol) {
        self.priceAssetInfoFactory = priceAssetInfoFactory
    }
}

extension SubtensorStkStateViewModelFactory {
    /// single source of the claimable figure so the reward row and the claim alert cannot disagree
    func eligibleClaimableTotal(for commonData: SubtensorStakingCommonData) -> Balance? {
        let claimableThreshold = commonData.networkInfo?.rootClaimableThreshold ??
            SubtensorStakingPallet.defaultRootClaimableThreshold

        return commonData.claimable.map {
            $0.claimState(threshold: claimableThreshold).eligibleTotal
        }
    }

    /// root rewards are a manual claim, so a compounding note may only appear when the list
    /// actually contains a subnet position (spec §6.5 vs §6.6)
    func hasAlphaPositions(in stakingState: Multistaking.SubtensorStakingState) -> Bool {
        stakingState.positions.contains { $0.netuid != SubtensorStakingPallet.rootNetuid }
    }

    func createStakingStatus(
        for stakingState: Multistaking.SubtensorStakingState
    ) -> NominationViewStatus {
        stakingState.positions.contains { $0.isRegistered } ? .active : .inactive
    }

    func createStakingViewModel(
        for chainAsset: ChainAsset,
        commonData: SubtensorStakingCommonData,
        stakingState: Multistaking.SubtensorStakingState,
        viewStatus: NominationViewStatus
    ) -> LocalizableResource<NominationViewModel> {
        let displayInfo = chainAsset.assetDisplayInfo
        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: displayInfo,
            priceAssetInfoFactory: priceAssetInfoFactory
        )

        let stakedAmount = stakingState.totalStakeInRao.decimal(assetInfo: displayInfo)

        let staked = balanceViewModelFactory.balanceFromPrice(
            stakedAmount,
            priceData: commonData.price
        )

        let hasAlphaPositions = stakingState.positions.contains {
            $0.netuid != SubtensorStakingPallet.rootNetuid
        }

        return LocalizableResource { locale in
            let stakedViewModel = staked.value(for: locale)
            let hasPrice = commonData.price != nil

            let amount = hasAlphaPositions
                ? stakedViewModel.amount.approximately()
                : stakedViewModel.amount

            return NominationViewModel(
                totalStakedAmount: amount,
                totalStakedPrice: stakedViewModel.price ?? "",
                status: viewStatus,
                hasPrice: hasPrice
            )
        }
    }

    func createStakingRewardViewModel(
        for chainAsset: ChainAsset,
        commonData: SubtensorStakingCommonData
    ) -> LocalizableResource<StakingRewardViewModel> {
        let assetInfo = chainAsset.assetDisplayInfo
        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: assetInfo,
            priceAssetInfoFactory: priceAssetInfoFactory
        )

        let localizedTotalRewards = commonData.totalReward.map { rewards in
            balanceViewModelFactory.balanceFromPrice(
                rewards.amount.decimalValue,
                priceData: commonData.price
            )
        }

        let eligibleClaimable = eligibleClaimableTotal(for: commonData)

        let localizedClaimableRewards = eligibleClaimable.map { eligibleTotal in
            balanceViewModelFactory.balanceFromPrice(
                eligibleTotal.decimal(assetInfo: assetInfo),
                priceData: commonData.price
            )
        }

        let localizedFilter = commonData.totalRewardFilter.map { $0.title(calendar: calendar) }

        let canClaimRewards = eligibleClaimable.map { $0 > 0 } ?? false

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
                graphics: R.image.imageStakingTypeDirect(),
                filter: filter,
                hasPrice: chainAsset.asset.hasPrice
            )
        }
    }

    func createStakedStateManageOptions(
        for state: SubtensorStakingStakedState
    ) -> [StakingManageOption] {
        [
            .stakeMore,
            .unstake,
            .changeValidators(count: state.stakingState.positions.count)
        ]
    }
}

extension SubtensorStkStateViewModelFactory: SubtensorStakingStateVisitorProtocol {
    func visit(state _: SubtensorStakingInitState) {
        lastViewModel = .undefined
    }

    func visit(state _: SubtensorStakingNotStakedState) {
        lastViewModel = .undefined
    }

    func visit(state: SubtensorStakingStakedState) {
        guard let chainAsset = state.commonData.chainAsset else {
            lastViewModel = .undefined
            return
        }

        let status = createStakingStatus(for: state.stakingState)

        let stakingViewModel = createStakingViewModel(
            for: chainAsset,
            commonData: state.commonData,
            stakingState: state.stakingState,
            viewStatus: status
        )

        let alerts = createAlerts(for: state.stakingState, commonData: state.commonData)

        let reward = createStakingRewardViewModel(for: chainAsset, commonData: state.commonData)

        let actions = createStakedStateManageOptions(for: state)

        lastViewModel = .nominator(
            viewModel: stakingViewModel,
            alerts: alerts,
            reward: reward,
            unbondings: nil,
            actions: actions
        )
    }
}

extension SubtensorStkStateViewModelFactory: SubtensorStkStateViewModelFactoryProtocol {
    func createViewModel(from state: SubtensorStakingStateProtocol) -> StakingViewState {
        state.accept(visitor: self)
        return lastViewModel
    }

    func createNetworkInfoViewModel(
        from networkInfo: SubtensorNetworkInfo,
        chainAsset: ChainAsset,
        price: PriceData?,
        locale: Locale
    ) -> NetworkStakingInfoViewModel {
        let displayInfo = chainAsset.assetDisplayInfo
        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: displayInfo,
            priceAssetInfoFactory: priceAssetInfoFactory
        )

        let minStakeDecimal = networkInfo.minStake.decimal(assetInfo: displayInfo)

        let minStakeViewModel = balanceViewModelFactory.balanceFromPrice(
            minStakeDecimal,
            priceData: price
        ).value(for: locale)

        return NetworkStakingInfoViewModel(
            totalStake: nil,
            minimalStake: .loaded(value: minStakeViewModel),
            activeNominators: nil,
            stakingPeriod: nil,
            lockUpPeriod: nil
        )
    }

    func createPositionViewModels(
        for stakingState: Multistaking.SubtensorStakingState,
        commonData: SubtensorStakingCommonData,
        selectable: Bool
    ) -> [AccountDetailsPickerViewModel] {
        guard let chainAsset = commonData.chainAsset else {
            return []
        }

        let identities = (commonData.delegates ?? []).reduce(
            into: [AccountId: AccountIdentity]()
        ) { accum, delegate in
            accum[delegate.info.delegateSs58] = delegate.identity
        }

        return stakingState.positions.sortedForSubtensorDisplay().map { position in
            createPositionViewModel(
                for: position,
                chainAsset: chainAsset,
                identities: identities,
                subnetsInfo: commonData.subnetsInfo,
                selectable: selectable
            )
        }
    }
}

private extension SubtensorStkStateViewModelFactory {
    /// spec §6.1 — the position's share of one tempo of hotkey-wide dividends, annualised to a day.
    /// Root positions are structurally excluded: the runtime never writes alpha dividends for the
    /// root subnet, so a rate there would be a fabricated zero rather than an estimate.
    func createRateSuffix(
        for position: SubtensorStakingPosition,
        displayInfo: AssetBalanceDisplayInfo,
        subnetsInfo: SubtensorSubnetsInfo?
    ) -> LocalizableResource<String>? {
        let tempo = subnetsInfo?.subnets.first { $0.netuid == position.netuid }?.tempo

        guard
            let perDayRao = SubtensorPositionRateCalculator.alphaPerDayRao(
                for: position,
                tempo: tempo
            ),
            perDayRao > 0 else {
            return nil
        }

        let formatter = AssetBalanceFormatterFactory().createTokenFormatter(for: displayInfo)
        let perDayDecimal = perDayRao.decimal(assetInfo: displayInfo)

        return LocalizableResource { locale in
            let amount = formatter.value(for: locale).stringFromDecimal(perDayDecimal) ?? ""

            return R.string(
                preferredLanguages: locale.rLanguages
            ).localizable.stakingSubtensorRatePerDayFormat(amount)
        }
    }
}

private extension SubtensorStkStateViewModelFactory {
    func createPositionViewModel(
        for position: SubtensorStakingPosition,
        chainAsset: ChainAsset,
        identities: [AccountId: AccountIdentity],
        subnetsInfo: SubtensorSubnetsInfo?,
        selectable: Bool
    ) -> AccountDetailsPickerViewModel {
        let addressViewModel: DisplayAddressViewModel
        let address = try? position.hotkey.toAddress(using: chainAsset.chain.chainFormat)

        if let name = identities[position.hotkey]?.displayName {
            let displayAddress = DisplayAddress(address: address ?? "", username: name)
            addressViewModel = displayAddressFactory.createViewModel(from: displayAddress)
        } else {
            addressViewModel = displayAddressFactory.createViewModel(from: address ?? "")
        }

        let displayInfo = createPositionDisplayInfo(
            for: position,
            chainAsset: chainAsset,
            subnetsInfo: subnetsInfo
        )

        let formatter = AssetBalanceFormatterFactory().createTokenFormatter(for: displayInfo)

        let amountDecimal = position.stakeAlpha.decimal(assetInfo: displayInfo)

        let rateSuffix = createRateSuffix(
            for: position,
            displayInfo: displayInfo,
            subnetsInfo: subnetsInfo
        )

        return LocalizableResource { locale in
            let detailsTitle = R.string(preferredLanguages: locale.rLanguages).localizable.commonStakedPrefix()
            let amount = formatter.value(for: locale).stringFromDecimal(amountDecimal) ?? ""

            let detailsSubtitle = rateSuffix.map { "\(amount) · \($0.value(for: locale))" } ?? amount

            let details = TitleWithSubtitleViewModel(title: detailsTitle, subtitle: detailsSubtitle)

            let accountDetails = AccountDetailsSelectionViewModel(
                displayAddress: addressViewModel,
                details: details
            )

            return SelectableViewModel(underlyingViewModel: accountDetails, selectable: selectable)
        }
    }

    func createPositionDisplayInfo(
        for position: SubtensorStakingPosition,
        chainAsset: ChainAsset,
        subnetsInfo: SubtensorSubnetsInfo?
    ) -> AssetBalanceDisplayInfo {
        guard position.netuid != SubtensorStakingPallet.rootNetuid else {
            return chainAsset.assetDisplayInfo
        }

        let subnetSymbol = subnetsInfo?.subnets
            .first { $0.netuid == position.netuid }?
            .displaySymbol

        let taoDisplayInfo = chainAsset.assetDisplayInfo

        return AssetBalanceDisplayInfo(
            displayPrecision: taoDisplayInfo.displayPrecision,
            assetPrecision: taoDisplayInfo.assetPrecision,
            symbol: subnetSymbol ?? "SN\(position.netuid)",
            symbolValueSeparator: taoDisplayInfo.symbolValueSeparator,
            symbolPosition: taoDisplayInfo.symbolPosition,
            icon: nil
        )
    }
}
