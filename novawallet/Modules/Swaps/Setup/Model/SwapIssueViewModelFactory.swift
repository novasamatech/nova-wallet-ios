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
        if model.isPayAmountHidden {
            return model.payAssetBalance?.transferable == 0 ? .insufficientBalance : nil
        }

        guard
            let payAmount = model.payAmount,
            payAmount > 0,
            let payChainAsset = model.payChainAsset,
            let transferable = model.payAssetBalance?.transferable
        else {
            return nil
        }

        let assetDisplayInfo = payChainAsset.assetDisplayInfo
        let balance = transferable.decimal(assetInfo: assetDisplayInfo)
        let fee = model.fee?.totalFeeInAssetIn(payChainAsset).decimal(assetInfo: assetDisplayInfo) ?? 0

        if payAmount + fee > balance {
            return .insufficientBalance
        }

        return model.isFeePending && model.wasShowingInsufficientBalance ? .insufficientBalance : nil
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

    func detectNoLiquidity(in model: SwapIssueCheckParams) -> SwapSetupViewIssue? {
        guard case let .failure(error) = model.quoteResult else {
            return nil
        }

        switch SwapQuoteFailure(error: error) {
        case .noLiquidity:
            return .noLiqudity
        case .noRoute, .fetchFailed:
            return .quoteUnavailable
        }
    }
}

extension SwapIssueViewModelFactory: SwapIssueViewModelFactoryProtocol {
    func detectIssues(in model: SwapIssueCheckParams, locale: Locale) -> [SwapSetupViewIssue] {
        [
            detectZeroBalance(in: model),
            detectZeroReceiveAmount(in: model),
            detectInsufficientBalance(in: model),
            detectMinBalanceViolationOnReceive(in: model, locale: locale),
            detectNoLiquidity(in: model)
        ].compactMap { $0 }
    }
}
