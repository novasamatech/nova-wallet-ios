import Foundation
import Foundation_iOS
import BigInt

protocol StakingDashboardViewModelFactoryProtocol {
    func createActiveStakingViewModel(
        for model: StakingDashboardItemModel.Concrete,
        singleActive: Bool,
        locale: Locale
    ) -> StakingDashboardEnabledViewModel

    func createInactiveStakingViewModel(
        for model: StakingDashboardItemModel,
        locale: Locale
    ) -> StakingDashboardDisabledViewModel

    func createUpdateViewModel(
        from model: StakingDashboardModel,
        syncChange: StakingDashboardBuilderResult.SyncChange,
        locale: Locale
    ) -> StakingDashboardUpdateViewModel

    func createViewModel(
        from model: StakingDashboardModel,
        locale: Locale
    ) -> StakingDashboardViewModel
}

final class StakingDashboardViewModelFactory {
    let networkViewModelFactory: NetworkViewModelFactoryProtocol
    let priceAssetInfoFactory: PriceAssetInfoFactoryProtocol
    let assetFormatterFactory: AssetBalanceFormatterFactoryProtocol
    let estimatedEarningsFormatter: LocalizableResource<NumberFormatter>

    init(
        assetFormatterFactory: AssetBalanceFormatterFactoryProtocol,
        priceAssetInfoFactory: PriceAssetInfoFactoryProtocol,
        networkViewModelFactory: NetworkViewModelFactoryProtocol,
        estimatedEarningsFormatter: LocalizableResource<NumberFormatter>
    ) {
        self.assetFormatterFactory = assetFormatterFactory
        self.priceAssetInfoFactory = priceAssetInfoFactory
        self.networkViewModelFactory = networkViewModelFactory
        self.estimatedEarningsFormatter = estimatedEarningsFormatter
    }

    private func createEstimatedEarnings(
        from value: Decimal?,
        isSyncing: Bool,
        locale: Locale
    ) -> LoadableViewModelState<String?> {
        guard let value = value else {
            return isSyncing ? .loading : .loaded(value: nil)
        }

        guard let valueString = estimatedEarningsFormatter.value(for: locale).stringFromDecimal(value) else {
            return isSyncing ? .loading : .loaded(value: nil)
        }

        return isSyncing ? .cached(value: valueString) : .loaded(value: valueString)
    }

    private func createAmount(
        for value: BigUInt?,
        priceData: PriceData?,
        assetDisplayInfo: AssetBalanceDisplayInfo,
        isSyncing: Bool,
        locale: Locale
    ) -> LoadableViewModelState<BalanceViewModelProtocol> {
        guard
            let value = value,
            let decimalValue = Decimal.fromSubstrateAmount(value, precision: assetDisplayInfo.assetPrecision) else {
            return .loading
        }

        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: assetDisplayInfo,
            priceAssetInfoFactory: priceAssetInfoFactory,
            formatterFactory: assetFormatterFactory
        )

        let viewModel = balanceViewModelFactory.balanceFromPrice(
            decimalValue,
            priceData: priceData ?? PriceData.zero()
        ).value(for: locale)

        return isSyncing ? .cached(value: viewModel) : .loaded(value: viewModel)
    }

    private func createStakingStatus(
        for model: StakingDashboardItemModel.Concrete
    ) -> LoadableViewModelState<StakingDashboardEnabledViewModel.Status> {
        guard let dashboardItem = model.dashboardItem else {
            return .loading
        }

        let state = StakingDashboardEnabledViewModel.Status(dashboardItem: dashboardItem)
        return model.hasAnySync ? .cached(value: state) : .loaded(value: state)
    }

    private func createStakingType(
        for model: StakingDashboardItemModel,
        locale: Locale
    ) -> TitleIconViewModel? {
        switch model {
        case let .concrete(concrete):
            return createStakingType(
                for: concrete.stakingOption,
                singleActive: false,
                locale: locale
            )
        case .combined:
            return nil
        }
    }

    private func createStakingType(
        for stakingOption: Multistaking.ChainAssetOption,
        singleActive: Bool,
        locale: Locale
    ) -> TitleIconViewModel? {
        guard !singleActive else {
            return nil
        }

        let stakings = stakingOption.chainAsset.asset.supportedStakings ?? []

        guard stakings.count > 1 else {
            return nil
        }

        switch stakingOption.type {
        case .auraRelaychain, .azero, .relaychain:
            return TitleIconViewModel(
                title: R.string(preferredLanguages: locale.rLanguages).localizable.stakingDirect().uppercased(),
                icon: R.image.iconStakingDirect()
            )

        case .nominationPools:
            return TitleIconViewModel(
                title: R.string(preferredLanguages: locale.rLanguages).localizable.stakingPool().uppercased(),
                icon: R.image.iconStakingPool()
            )
        case .parachain, .turing, .mythos, .unsupported:
            return nil
        }
    }
}

extension StakingDashboardViewModelFactory: StakingDashboardViewModelFactoryProtocol {
    func createActiveStakingViewModel(
        for model: StakingDashboardItemModel.Concrete,
        singleActive: Bool,
        locale: Locale
    ) -> StakingDashboardEnabledViewModel {
        let chainAsset = model.chainAsset
        let assetDisplayInfo = chainAsset.assetDisplayInfo

        let networkViewModel = networkViewModelFactory.createViewModel(
            from: chainAsset.chain
        )

        let estimatedEarnings = createEstimatedEarnings(
            from: model.dashboardItem?.maxApy,
            isSyncing: model.isOffchainSync,
            locale: locale
        )

        let totalRewards = createAmount(
            for: model.dashboardItem?.totalRewards ?? 0,
            priceData: model.price,
            assetDisplayInfo: assetDisplayInfo,
            isSyncing: model.isOffchainSync,
            locale: locale
        )

        let yourStake = createAmount(
            for: model.dashboardItem?.stake,
            priceData: model.price,
            assetDisplayInfo: assetDisplayInfo,
            isSyncing: model.isOnchainSync,
            locale: locale
        )

        let status = createStakingStatus(for: model)

        let network: LoadableViewModelState<NetworkViewModel> = model.hasAnySync ?
            .cached(value: networkViewModel) : .loaded(value: networkViewModel)

        let stakingType = createStakingType(
            for: model.stakingOption,
            singleActive: singleActive,
            locale: locale
        )

        return .init(
            networkViewModel: network,
            totalRewards: totalRewards,
            status: status,
            yourStake: yourStake,
            estimatedEarnings: estimatedEarnings,
            stakingType: stakingType
        )
    }

    func createInactiveStakingViewModel(
        for model: StakingDashboardItemModel,
        locale: Locale
    ) -> StakingDashboardDisabledViewModel {
        let chainAsset = model.chainAsset
        let assetDisplayInfo = chainAsset.assetDisplayInfo

        let networkViewModel = networkViewModelFactory.createViewModel(
            from: chainAsset.chain
        )

        let estimatedEarnings = createEstimatedEarnings(
            from: model.maxApy,
            isSyncing: model.isOffchainSync,
            locale: locale
        )

        let balance = createAmount(
            for: model.availableBalance,
            priceData: model.price,
            assetDisplayInfo: assetDisplayInfo,
            isSyncing: false,
            locale: locale
        ).value?.amount

        let network: LoadableViewModelState<NetworkViewModel> = model.hasAnySync ?
            .cached(value: networkViewModel) : .loaded(value: networkViewModel)

        let stakingType = createStakingType(for: model, locale: locale)

        return .init(
            networkViewModel: network,
            estimatedEarnings: estimatedEarnings,
            balance: balance,
            stakingType: stakingType
        )
    }

    func createViewModel(
        from model: StakingDashboardModel,
        locale: Locale
    ) -> StakingDashboardViewModel {
        let activeCounters = model.getActiveCounters()

        let activeViewModels = model.active.map {
            let counter = activeCounters[$0.chainAsset.chainAssetId] ?? 0

            return createActiveStakingViewModel(
                for: $0,
                singleActive: counter <= 1,
                locale: locale
            )
        }

        let inactiveViewModels = model.inactive.map {
            createInactiveStakingViewModel(
                for: .combined($0),
                locale: locale
            )
        }

        let isLoading = model.isEmpty

        return .init(
            active: activeViewModels,
            inactive: inactiveViewModels,
            hasMoreOptions: true,
            isLoading: isLoading,
            isSyncing: model.all.contains { $0.isOffchainSync }
        )
    }

    func createUpdateViewModel(
        from model: StakingDashboardModel,
        syncChange: StakingDashboardBuilderResult.SyncChange,
        locale: Locale
    ) -> StakingDashboardUpdateViewModel {
        let activeCounters = model.getActiveCounters()

        let activeViewModels: [(Int, StakingDashboardEnabledViewModel)] = model.active.enumerated().compactMap { item in
            guard syncChange.byStakingOption.contains(item.1.stakingOption) else {
                return nil
            }

            let counter = activeCounters[item.1.chainAsset.chainAssetId] ?? 0
            let viewModel = createActiveStakingViewModel(
                for: item.1,
                singleActive: counter <= 1,
                locale: locale
            )

            return (item.0, viewModel)
        }

        let inactiveViewModels: [(Int, StakingDashboardDisabledViewModel)] = model.inactive
            .enumerated().compactMap { item in
                guard syncChange.byStakingChainAsset.contains(item.1.chainAsset) else {
                    return nil
                }

                let viewModel = createInactiveStakingViewModel(
                    for: .combined(item.1),
                    locale: locale
                )

                return (item.0, viewModel)
            }

        return .init(
            active: activeViewModels,
            inactive: inactiveViewModels,
            isSyncing: model.all.contains { $0.isOffchainSync }
        )
    }
}
