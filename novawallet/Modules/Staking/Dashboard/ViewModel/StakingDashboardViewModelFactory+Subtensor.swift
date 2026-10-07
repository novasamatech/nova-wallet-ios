import Foundation

extension StakingDashboardViewModelFactory {
    func createSubtensorActiveStakingViewModel(
        for model: StakingDashboardItemModel.Concrete,
        announcement: AnnouncementViewModel?,
        privacyModeEnabled: Bool,
        singleActive: Bool,
        locale: Locale
    ) -> StakingDashboardEnabledViewModel {
        let strings = R.string(preferredLanguages: locale.rLanguages).localizable
        let details = model.dashboardItem?.subtensorDetails

        let chainAssetViewModel = chainAssetViewModelFactory.createViewModel(from: model.chainAsset)

        let composition = details.flatMap { createSubtensorComposition(for: $0, locale: locale) }

        let title = composition.map {
            strings.stakingSubtensorUiJoinDotFormat(chainAssetViewModel.assetName, $0)
        } ?? chainAssetViewModel.assetName

        let amount = createSubtensorTotalStake(for: model, details: details, locale: locale)

        let rootStake = createAmount(
            for: details.map { $0.rootStake ?? 0 },
            priceData: model.price,
            assetDisplayInfo: model.chainAsset.assetDisplayInfo,
            isSyncing: model.isOnchainSync,
            locale: locale
        )

        let hasRootStake = details.map { $0.rootStake != nil } ?? true

        let estimatedEarnings = createEstimatedEarnings(
            from: hasRootStake ? details?.rootRate : nil,
            isSyncing: hasRootStake && model.isOnchainSync,
            locale: locale
        )

        let stakingType = createStakingType(
            for: model.stakingOption,
            singleActive: singleActive,
            locale: locale
        )

        return .init(
            chainAssetViewModel: chainAssetViewModel,
            title: title,
            amount: .wrapped(amount, with: privacyModeEnabled),
            status: createStakingStatus(for: model),
            stakeTitle: strings.stakingSubtensorUiDashboardRoot(),
            yourStake: .wrapped(rootStake, with: privacyModeEnabled),
            estimatedEarnings: estimatedEarnings,
            stakingType: stakingType,
            announcement: announcement
        )
    }
}

private extension StakingDashboardViewModelFactory {
    func createSubtensorTotalStake(
        for model: StakingDashboardItemModel.Concrete,
        details: Multistaking.DashboardItemSubtensorDetails?,
        locale: Locale
    ) -> LoadableViewModelState<BalanceViewModelProtocol> {
        let strings = R.string(preferredLanguages: locale.rLanguages).localizable

        if details?.isFullyPriced == false {
            let unknownTotal = BalanceViewModel(amount: strings.stakingSubtensorUiValueUnknown(), price: nil)

            return model.isOnchainSync ? .cached(value: unknownTotal) : .loaded(value: unknownTotal)
        }

        if let details, details.isFullyPriced == nil {
            return .loading
        }

        let totalStake = createAmount(
            for: model.dashboardItem?.stake,
            priceData: model.price,
            assetDisplayInfo: model.chainAsset.assetDisplayInfo,
            isSyncing: model.isOnchainSync,
            locale: locale
        )

        guard (details?.subnetCount ?? 0) > 0 else {
            return totalStake
        }

        return totalStake.map { viewModel -> BalanceViewModelProtocol in
            BalanceViewModel(
                amount: viewModel.amount,
                price: viewModel.price.map { strings.stakingSubtensorUiDashboardEstimatedFormat($0) }
            )
        }
    }

    func createSubtensorComposition(
        for details: Multistaking.DashboardItemSubtensorDetails,
        locale: Locale
    ) -> String? {
        let strings = R.string(preferredLanguages: locale.rLanguages).localizable

        switch (details.rootStake != nil, details.subnetCount > 0) {
        case (true, true):
            return strings.stakingSubtensorUiDashboardRootSubnets(format: details.subnetCount)
        case (true, false):
            return strings.stakingSubtensorUiDashboardRoot()
        case (false, true):
            return strings.stakingSubtensorUiDashboardSubnets(format: details.subnetCount)
        case (false, false):
            return nil
        }
    }
}
