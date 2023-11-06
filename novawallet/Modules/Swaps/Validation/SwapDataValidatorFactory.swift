import Foundation
import BigInt
import SoraFoundation

protocol SwapDataValidatorFactoryProtocol: BaseDataValidatingFactoryProtocol {
    func hasSufficientBalance(
        params: SwapModel,
        swapMaxAction: @escaping () -> Void,
        locale: Locale
    ) -> DataValidating

    func canReceive(params: SwapModel, locale: Locale) -> DataValidating

    func noDustRemains(
        params: SwapModel,
        swapMaxAction: @escaping () -> Void,
        locale: Locale
    ) -> DataValidating

    func has(
        quote: AssetConversion.Quote?,
        payChainAssetId: ChainAssetId?,
        receiveChainAssetId: ChainAssetId?,
        locale: Locale,
        onError: (() -> Void)?
    ) -> DataValidating
}

final class SwapDataValidatorFactory: SwapDataValidatorFactoryProtocol {
    weak var view: (Localizable & ControllerBackedProtocol)?

    var basePresentable: BaseErrorPresentable { presentable }

    let presentable: SwapErrorPresentable
    let balanceViewModelFactoryFacade: BalanceViewModelFactoryFacadeProtocol

    init(
        presentable: SwapErrorPresentable,
        balanceViewModelFactoryFacade: BalanceViewModelFactoryFacadeProtocol
    ) {
        self.presentable = presentable
        self.balanceViewModelFactoryFacade = balanceViewModelFactoryFacade
    }

    // swiftlint:disable:next function_body_length
    func hasSufficientBalance(
        params: SwapModel,
        swapMaxAction: @escaping () -> Void,
        locale: Locale
    ) -> DataValidating {
        let insufficientReason = params.checkBalanceSufficiency()

        return ErrorConditionViolation(onError: { [weak self] in
            guard
                let view = self?.view,
                let reason = insufficientReason,
                let viewModelFactory = self?.balanceViewModelFactoryFacade else {
                return
            }

            switch reason {
            case .amountToHigh:
                self?.presentable.presentAmountTooHigh(from: view, locale: locale)
            case let .feeInNativeAsset(model):
                let params = SwapDisplayError.InsufficientBalanceDueFeeNativeAsset(
                    available: viewModelFactory.amountFromValue(
                        targetAssetInfo: params.payChainAsset.assetDisplayInfo,
                        value: model.available
                    ).value(for: locale),
                    fee: viewModelFactory.amountFromValue(
                        targetAssetInfo: params.feeChainAsset.assetDisplayInfo,
                        value: model.fee
                    ).value(for: locale)
                )

                self?.presentable.presentInsufficientBalance(
                    from: view,
                    reason: .dueFeeNativeAsset(params),
                    action: swapMaxAction,
                    locale: locale
                )
            case let .feeInPayAsset(model):
                let utilityChainAsset = params.utilityChainAsset ?? params.feeChainAsset

                let params = SwapDisplayError.InsufficientBalanceDueFeePayAsset(
                    available: viewModelFactory.amountFromValue(
                        targetAssetInfo: params.payChainAsset.assetDisplayInfo,
                        value: model.available
                    ).value(for: locale),
                    fee: viewModelFactory.amountFromValue(
                        targetAssetInfo: params.feeChainAsset.assetDisplayInfo,
                        value: model.feeInPayAsset
                    ).value(for: locale),
                    minBalanceInPayAsset: viewModelFactory.amountFromValue(
                        targetAssetInfo: params.payChainAsset.assetDisplayInfo,
                        value: model.minBalanceInPayAsset
                    ).value(for: locale),
                    minBalanceInUtilityAsset: viewModelFactory.amountFromValue(
                        targetAssetInfo: utilityChainAsset.assetDisplayInfo,
                        value: model.minBalanceInNativeAsset
                    ).value(for: locale),
                    tokenSymbol: utilityChainAsset.asset.symbol
                )

                self?.presentable.presentInsufficientBalance(
                    from: view,
                    reason: .dueFeePayAsset(params),
                    action: swapMaxAction,
                    locale: locale
                )
            case let .violatingConsumers(model):
                let utilityChainAsset = params.utilityChainAsset ?? params.feeChainAsset

                let params = SwapDisplayError.InsufficientBalanceDueConsumers(
                    minBalance: viewModelFactory.amountFromValue(
                        targetAssetInfo: utilityChainAsset.assetDisplayInfo,
                        value: model.minBalance
                    ).value(for: locale),
                    fee: viewModelFactory.amountFromValue(
                        targetAssetInfo: params.feeChainAsset.assetDisplayInfo,
                        value: model.fee
                    ).value(for: locale)
                )

                self?.presentable.presentInsufficientBalance(
                    from: view,
                    reason: .dueConsumers(params),
                    action: swapMaxAction,
                    locale: locale
                )
            }

            self?.presentable.presentNotEnoughLiquidity(from: view, locale: locale)
        }, preservesCondition: {
            insufficientReason == nil
        })
    }

    func canReceive(params: SwapModel, locale: Locale) -> DataValidating {
        let cantReceiveReason = params.checkCanReceive()

        return ErrorConditionViolation(onError: { [weak self] in
            guard
                let view = self?.view,
                let reason = cantReceiveReason,
                let viewModelFactory = self?.balanceViewModelFactoryFacade else {
                return
            }

            switch reason {
            case let .existense(model):
                self?.presentable.presentMinBalanceViolatedToReceive(
                    from: view,
                    minBalance: viewModelFactory.amountFromValue(
                        targetAssetInfo: params.receiveChainAsset.assetDisplayInfo,
                        value: model.minBalance
                    ).value(for: locale),
                    locale: locale
                )
            case let .noProvider(model):
                let utilityChainAsset = params.utilityChainAsset ?? params.feeChainAsset

                self?.presentable.presentNoProviderForNonSufficientToken(
                    from: view,
                    utilityMinBalance: viewModelFactory.amountFromValue(
                        targetAssetInfo: utilityChainAsset.assetDisplayInfo,
                        value: model.minBalance
                    ).value(for: locale),
                    token: params.receiveChainAsset.asset.symbol,
                    locale: locale
                )
            }

        }, preservesCondition: {
            cantReceiveReason == nil
        })
    }

    // swiftlint:disable:next function_body_length
    func noDustRemains(
        params: SwapModel,
        swapMaxAction: @escaping () -> Void,
        locale: Locale
    ) -> DataValidating {
        let dustReason = params.checkDustAfterSwap()

        return WarningConditionViolation(onWarning: { [weak self] delegate in
            guard
                let view = self?.view,
                let viewModelFactory = self?.balanceViewModelFactoryFacade,
                let reason = dustReason else {
                return
            }

            let errorReason: SwapDisplayError.DustRemains

            switch reason {
            case let .swap(model):
                let params = SwapDisplayError.DustRemainsDueNativeSwap(
                    remaining: viewModelFactory.amountFromValue(
                        targetAssetInfo: params.payChainAsset.assetDisplayInfo,
                        value: model.dust
                    ).value(for: locale),
                    minBalance: viewModelFactory.amountFromValue(
                        targetAssetInfo: params.payChainAsset.assetDisplayInfo,
                        value: model.minBalance
                    ).value(for: locale)
                )

                errorReason = .dueNativeSwap(params)
            case let .swapAndFee(model):
                let utilityChainAsset = params.utilityChainAsset ?? params.feeChainAsset

                let params = SwapDisplayError.DustRemainsDueFeeSwap(
                    remaining: viewModelFactory.amountFromValue(
                        targetAssetInfo: params.payChainAsset.assetDisplayInfo,
                        value: model.dust
                    ).value(for: locale),
                    minBalanceOfPayAsset: viewModelFactory.amountFromValue(
                        targetAssetInfo: params.payChainAsset.assetDisplayInfo,
                        value: model.minBalance
                    ).value(for: locale),
                    fee: viewModelFactory.amountFromValue(
                        targetAssetInfo: params.feeChainAsset.assetDisplayInfo,
                        value: model.fee
                    ).value(for: locale),
                    minBalanceInPayAsset: viewModelFactory.amountFromValue(
                        targetAssetInfo: params.payChainAsset.assetDisplayInfo,
                        value: model.minBalanceInPayAsset
                    ).value(for: locale),
                    minBalanceInUtilityAsset: viewModelFactory.amountFromValue(
                        targetAssetInfo: utilityChainAsset.assetDisplayInfo,
                        value: model.minBalanceInNativeAsset
                    ).value(for: locale),
                    utilitySymbol: utilityChainAsset.asset.symbol
                )

                errorReason = .dueFeeSwap(params)
            }

            self?.presentable.presentDustRemains(
                from: view,
                reason: errorReason,
                swapMaxAction: swapMaxAction,
                proceedAction: {
                    delegate.didCompleteWarningHandling()
                },
                locale: locale
            )

        }, preservesCondition: {
            dustReason == nil
        })
    }

    func has(
        quote: AssetConversion.Quote?,
        payChainAssetId: ChainAssetId?,
        receiveChainAssetId: ChainAssetId?,
        locale: Locale,
        onError: (() -> Void)?
    ) -> DataValidating {
        ErrorConditionViolation(onError: { [weak self] in
            defer {
                onError?()
            }

            guard let view = self?.view else {
                return
            }
            self?.presentable.presentNotEnoughLiquidity(from: view, locale: locale)
        }, preservesCondition: {
            guard let quote = quote else {
                return false
            }
            return quote.assetIn == payChainAssetId && quote.assetOut == receiveChainAssetId
        })
    }
}
