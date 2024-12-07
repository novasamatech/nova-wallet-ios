import Foundation
import BigInt
import SoraFoundation

typealias SwapRemoteValidatingClosure = (AssetConversion.QuoteArgs, @escaping SwapModel.QuoteValidateClosure) -> Void

struct SwapInterEDValidatingParams {
    let operations: [AssetExchangeMetaOperationProtocol]
    let completionClosure: SwapInterEDCheckClosure
}

typealias SwapInterEDValidatingClosure = (SwapInterEDValidatingParams) -> Void

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

    func passesRealtimeQuoteValidation(
        params: SwapModel,
        remoteValidatingClosure: @escaping SwapRemoteValidatingClosure,
        onQuoteUpdate: @escaping (AssetExchangeQuote) -> Void,
        locale: Locale
    ) -> DataValidating

    func passesIntermediateEDValidation(
        params: SwapModel,
        remoteValidatingClosure: @escaping SwapInterEDValidatingClosure,
        locale: Locale
    ) -> DataValidating
}

final class SwapDataValidatorFactory: SwapDataValidatorFactoryProtocol {
    weak var view: ControllerBackedProtocol?

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

    // swiftlint:disable:next function_body_length
    func passesRealtimeQuoteValidation(
        params: SwapModel,
        remoteValidatingClosure: @escaping SwapRemoteValidatingClosure,
        onQuoteUpdate: @escaping (AssetExchangeQuote) -> Void,
        locale: Locale
    ) -> DataValidating {
        var reason: SwapModel.InvalidQuoteReason?

        return AsyncWarningConditionViolation(
            onWarning: { [weak self] delegate in
                guard
                    let reason = reason,
                    let view = self?.view,
                    let viewModelFactory = self?.balanceViewModelFactoryFacade else {
                    return
                }

                switch reason {
                case let .rateChange(rateUpdate):
                    let oldRate = Decimal.rateFromSubstrate(
                        amount1: rateUpdate.oldQuote.route.amountIn,
                        amount2: rateUpdate.oldQuote.route.amountOut,
                        precision1: params.payChainAsset.assetDisplayInfo.assetPrecision,
                        precision2: params.receiveChainAsset.assetDisplayInfo.assetPrecision
                    ) ?? 0

                    let oldRateString = viewModelFactory.rateFromValue(
                        mainSymbol: params.payChainAsset.asset.symbol,
                        targetAssetInfo: params.receiveChainAsset.assetDisplayInfo,
                        value: oldRate
                    ).value(for: locale)

                    let newRate = Decimal.rateFromSubstrate(
                        amount1: rateUpdate.newQuote.route.amountIn,
                        amount2: rateUpdate.newQuote.route.amountOut,
                        precision1: params.payChainAsset.assetDisplayInfo.assetPrecision,
                        precision2: params.receiveChainAsset.assetDisplayInfo.assetPrecision
                    ) ?? 0

                    let newRateString = viewModelFactory.rateFromValue(
                        mainSymbol: params.payChainAsset.asset.symbol,
                        targetAssetInfo: params.receiveChainAsset.assetDisplayInfo,
                        value: newRate
                    ).value(for: locale)

                    self?.presentable.presentRateUpdated(
                        from: view,
                        oldRate: oldRateString,
                        newRate: newRateString,
                        onConfirm: {
                            onQuoteUpdate(rateUpdate.newQuote)
                            delegate.didCompleteAsyncHandling()
                        },
                        locale: locale
                    )

                case .noLiqudity:
                    self?.presentable.presentNotEnoughLiquidity(
                        from: view,
                        locale: locale
                    )
                }
            },
            preservesCondition: { preservationCallback in
                params.asyncCheckQuoteValidity(remoteValidatingClosure) { result in
                    let preserves = result == nil
                    reason = result

                    preservationCallback(preserves)
                }
            }
        )
    }

    func passesIntermediateEDValidation(
        params: SwapModel,
        remoteValidatingClosure: @escaping SwapInterEDValidatingClosure,
        locale _: Locale
    ) -> DataValidating {
        var reason: SwapInterEDNotMet?

        return AsyncErrorConditionViolation(
            onError: {
                guard let reason, let operations = params.quote?.metaOperations else {
                    return
                }

                // TODO: Present error on validation
            },
            preservesCondition: { preservationCallback in
                guard let operations = params.quote?.metaOperations else {
                    preservationCallback(true)
                    return
                }

                let closureParams = SwapInterEDValidatingParams(operations: operations) { result in
                    let preserves = result == nil
                    reason = result

                    preservationCallback(preserves)
                }

                remoteValidatingClosure(closureParams)
            }
        )
    }
}
