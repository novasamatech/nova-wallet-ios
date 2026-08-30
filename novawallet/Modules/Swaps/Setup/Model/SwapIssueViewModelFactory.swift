import Foundation

protocol SwapIssueViewModelFactoryProtocol {
    func detectIssues(in model: SwapIssueCheckParams, locale: Locale) -> [SwapSetupViewIssue]
}

final class SwapIssueViewModelFactory {
    let balanceViewModelFactoryFacade: BalanceViewModelFactoryFacadeProtocol

    init(balanceViewModelFactoryFacade: BalanceViewModelFactoryFacadeProtocol) {
        self.balanceViewModelFactoryFacade = balanceViewModelFactoryFacade
    }

    func detectZeroBalance(in model: SwapIssueCheckParams) -> SwapSetupViewIssue? {
        if let balance = model.payAssetBalance?.transferable, balance == 0 {
            return .zeroBalance
        } else {
            return nil
        }
    }

    func detectZeroReceiveAmount(in model: SwapIssueCheckParams) -> SwapSetupViewIssue? {
        if let receiveAmount = model.receiveAmount, receiveAmount == 0 {
            return .zeroReceiveAmount
        } else {
            return nil
        }
    }

    func detectInsufficientBalance(in model: SwapIssueCheckParams) -> SwapSetupViewIssue? {
        guard
            let payAmount = model.payAmount,
            payAmount > 0,
            let payChainAsset = model.payChainAsset
        else {
            return nil
        }

        let assetDisplayInfo = payChainAsset.assetDisplayInfo
        let balance = model.payAssetBalance?.transferable.decimal(assetInfo: assetDisplayInfo) ?? 0
        let fee = model.fee?.totalFeeInAssetIn(payChainAsset).decimal(assetInfo: assetDisplayInfo) ?? 0

        return payAmount + fee > balance ? .insufficientBalance : nil
    }

    func detectMinBalanceViolationOnReceive(in model: SwapIssueCheckParams, locale: Locale) -> SwapSetupViewIssue? {
        guard
            let receiveChainAsset = model.receiveChainAsset,
            let receiveAmount = model.receiveAmount,
            let minBalance = model.receiveAssetExistense?.minBalance.decimal(
                precision: receiveChainAsset.asset.precision
            ),
            let beforeSwapBalance = model.receiveAssetBalance?.balanceCountingEd.decimal(
                precision: receiveChainAsset.asset.precision
            ) else {
            return nil
        }

        guard beforeSwapBalance + receiveAmount < minBalance else {
            return nil
        }

        let minBalanceString = balanceViewModelFactoryFacade.amountFromValue(
            targetAssetInfo: receiveChainAsset.assetDisplayInfo,
            value: minBalance
        ).value(for: locale)

        return .minBalanceViolation(minBalanceString)
    }

    func detectPoolTradeLimit(in model: SwapIssueCheckParams, locale: Locale) -> SwapSetupViewIssue? {
        poolTradeLimit(in: model, locale: locale).map { .poolTradeLimit($0) }
    }

    func detectNoLiquidity(in model: SwapIssueCheckParams, locale: Locale) -> SwapSetupViewIssue? {
        guard
            case .failure = model.quoteResult,
            poolTradeLimit(in: model, locale: locale) == nil
        else {
            return nil
        }

        return .noLiqudity
    }
}

private extension SwapIssueViewModelFactory {
    /// Both pay-side quote-failure issues read this one classifier, so they are mutually exclusive by
    /// construction. Ordering them in `detectIssues` would not do: `displayPayIssue` reuses a single
    /// label, so whichever fires later overwrites the other and the cap message would never render.
    func poolTradeLimit(in model: SwapIssueCheckParams, locale: Locale) -> SwapPoolTradeLimitViewModel? {
        guard
            case let .failure(error) = model.quoteResult,
            let failure = error as? AssetExchangeTradeLimitFailure,
            let displayError = SwapDisplayError.PoolTradeLimit.build(
                from: failure,
                canApply: failure.isUserInputAdjustable && model.canApplyPoolTradeLimit,
                viewModelFactory: balanceViewModelFactoryFacade,
                locale: locale
            )
        else {
            return nil
        }

        return SwapPoolTradeLimitViewModel(
            message: displayError.message,
            applyTitle: displayError.applyTitle,
            side: SwapAmountFieldSide(direction: failure.direction)
        )
    }
}

extension SwapIssueViewModelFactory: SwapIssueViewModelFactoryProtocol {
    func detectIssues(in model: SwapIssueCheckParams, locale: Locale) -> [SwapSetupViewIssue] {
        [
            detectZeroBalance(in: model),
            detectZeroReceiveAmount(in: model),
            detectInsufficientBalance(in: model),
            detectMinBalanceViolationOnReceive(in: model, locale: locale),
            detectPoolTradeLimit(in: model, locale: locale),
            detectNoLiquidity(in: model, locale: locale)
        ].compactMap { $0 }
    }
}
