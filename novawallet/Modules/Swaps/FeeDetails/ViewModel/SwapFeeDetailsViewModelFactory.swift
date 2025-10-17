import Foundation

protocol SwapFeeDetailsViewModelFactoryProtocol {
    func createViewModel(
        from operations: [AssetExchangeMetaOperationProtocol],
        fee: AssetExchangeFee,
        locale: Locale
    ) -> SwapFeeDetailsViewModel
}

final class SwapFeeDetailsViewModelFactory {
    let balanceViewModelFacade: BalanceViewModelFactoryFacadeProtocol
    let priceAssetInfoFactory: PriceAssetInfoFactoryProtocol
    let priceStore: AssetExchangePriceStoring

    init(priceAssetInfoFactory: PriceAssetInfoFactoryProtocol, priceStore: AssetExchangePriceStoring) {
        self.priceAssetInfoFactory = priceAssetInfoFactory
        self.priceStore = priceStore
        balanceViewModelFacade = BalanceViewModelFactoryFacade(priceAssetInfoFactory: priceAssetInfoFactory)
    }
}

private extension SwapFeeDetailsViewModelFactory {
    func createType(
        from operation: AssetExchangeMetaOperationProtocol,
        locale: Locale
    ) -> String {
        switch operation.label {
        case .swap:
            R.string(preferredLanguages: locale.rLanguages).localizable.swapsLabelSwap()
        case .transfer:
            R.string(preferredLanguages: locale.rLanguages).localizable.swapsLabelTransfer()
        }
    }

    func createRoute(
        from operation: AssetExchangeMetaOperationProtocol,
        locale _: Locale
    ) -> [SwapRouteItemView.ViewModel] {
        switch operation.label {
        case .swap:
            [
                SwapRouteItemView.ViewModel(
                    title: operation.assetIn.chain.name,
                    icon: ImageViewModelFactory.createChainIconOrDefault(from: operation.assetIn.chain.icon)
                )
            ]
        case .transfer:
            [
                operation.assetIn.chain,
                operation.assetOut.chain
            ].map {
                SwapRouteItemView.ViewModel(
                    title: $0.name,
                    icon: ImageViewModelFactory.createChainIconOrDefault(from: $0.icon)
                )
            }
        }
    }

    func createFee(
        for amount: Balance,
        feeAssetId: ChainAssetId,
        chain: ChainModel,
        locale: Locale
    ) -> BalanceViewModelProtocol? {
        guard
            feeAssetId.chainId == chain.chainId,
            let assetDisplayInfo = chain.chainAsset(for: feeAssetId.assetId)?.assetDisplayInfo else {
            return nil
        }

        return balanceViewModelFacade.balanceFromPrice(
            targetAssetInfo: assetDisplayInfo,
            amount: amount.decimal(assetInfo: assetDisplayInfo),
            priceData: priceStore.fetchPrice(for: feeAssetId)
        ).value(for: locale)
    }

    func createNetworkFees(
        for operation: AssetExchangeMetaOperationProtocol,
        fee: AssetExchangeOperationFee,
        locale: Locale
    ) -> [BalanceViewModelProtocol] {
        if let networkFee = createFee(
            for: fee.submissionFee.amount,
            feeAssetId: fee.submissionFee.amountWithAsset.asset,
            chain: operation.assetIn.chain,
            locale: locale
        ) {
            return [networkFee]
        } else {
            return []
        }
    }

    func createCrosschainFees(
        for operation: AssetExchangeMetaOperationProtocol,
        fee: AssetExchangeOperationFee,
        locale: Locale
    ) -> [BalanceViewModelProtocol] {
        var crosschainFees: [BalanceViewModelProtocol] = []

        let postSubmissionFeeAssets = fee.postSubmissionFee.paidByAccount.map(\.amountWithAsset.asset) +
            fee.postSubmissionFee.paidFromAmount.map(\.asset)

        var groupByToken: [ChainAssetId: Balance] = [:]
        fee.postSubmissionFee.addAmount(to: &groupByToken)

        var addedFeeInAsset: Set<ChainAssetId> = Set()

        for asset in postSubmissionFeeAssets {
            if !addedFeeInAsset.contains(asset) {
                if let fee = createFee(
                    for: groupByToken[asset] ?? 0,
                    feeAssetId: asset,
                    chain: operation.assetIn.chain,
                    locale: locale
                ) {
                    crosschainFees.append(fee)
                    addedFeeInAsset.insert(asset)
                }
            }
        }

        return crosschainFees
    }

    func createOperationViewModel(
        for operation: AssetExchangeMetaOperationProtocol,
        fee: AssetExchangeOperationFee,
        locale: Locale
    ) -> SwapOperationFeeView.ViewModel {
        let type = createType(from: operation, locale: locale)
        let route = createRoute(from: operation, locale: locale)

        let networkFees = createNetworkFees(
            for: operation,
            fee: fee,
            locale: locale
        )

        let crosschainFees = createCrosschainFees(
            for: operation,
            fee: fee,
            locale: locale
        )

        var feeGroups: [SwapOperationFeeView.FeeGroup] = []

        if !networkFees.isEmpty {
            feeGroups.append(
                SwapOperationFeeView.FeeGroup(
                    title: R.string(preferredLanguages: locale.rLanguages).localizable.commonNetworkFee(),
                    amounts: networkFees
                )
            )
        }

        if !crosschainFees.isEmpty {
            feeGroups.append(
                SwapOperationFeeView.FeeGroup(
                    title: R.string(preferredLanguages: locale.rLanguages).localizable.commonCrossChainFee(),
                    amounts: crosschainFees
                )
            )
        }

        return SwapOperationFeeView.ViewModel(
            type: type,
            route: route,
            feeGroups: feeGroups
        )
    }

    func createTotalFee(
        operations: [AssetExchangeMetaOperationProtocol],
        fee: AssetExchangeFee,
        locale: Locale
    ) -> String {
        let totalAmountInFiat = fee.calculateTotalFeeInFiat(
            matching: operations,
            priceStore: priceStore
        )

        return balanceViewModelFacade.priceFromFiatAmount(
            totalAmountInFiat,
            currencyId: priceStore.getCurrencyId()
        ).value(for: locale)
    }
}

extension SwapFeeDetailsViewModelFactory: SwapFeeDetailsViewModelFactoryProtocol {
    func createViewModel(
        from operations: [AssetExchangeMetaOperationProtocol],
        fee: AssetExchangeFee,
        locale: Locale
    ) -> SwapFeeDetailsViewModel {
        let operationFeeViewModels = zip(operations, fee.operationFees).map { operation, fee in
            createOperationViewModel(for: operation, fee: fee, locale: locale)
        }

        let totalFee = createTotalFee(
            operations: operations,
            fee: fee,
            locale: locale
        )

        return SwapFeeDetailsViewModel(total: totalFee, operationFees: operationFeeViewModels)
    }
}
