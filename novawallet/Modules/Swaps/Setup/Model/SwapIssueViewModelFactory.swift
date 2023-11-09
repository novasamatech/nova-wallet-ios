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

    func detectInsufficientBalance(in model: SwapIssueCheckParams) -> SwapSetupViewIssue? {
        if let payAmount = model.payAmount,
           let payChainAsset = model.payChainAsset,
           let balance = model.payAssetBalance?.transferable.decimal(precision: payChainAsset.asset.precision),
           payAmount > balance {
            return .insufficientBalance
        } else {
            return nil
        }
    }

    func detectMinBalanceViolationOnReceive(in model: SwapIssueCheckParams, locale: Locale) -> SwapSetupViewIssue? {
        guard
            let receiveChainAsset = model.receiveChainAsset,
            let receiveAmount = model.receiveAmount,
            let minBalance = model.receiveAssetExistense?.minBalance.decimal(
                precision: receiveChainAsset.asset.precision
            ),
            let beforeSwapBalance = model.receiveAssetBalance?.freeInPlank.decimal(
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
        if case .failure = model.quoteResult {
            return .noLiqudity
        } else {
            return nil
        }
    }
}

extension SwapIssueViewModelFactory: SwapIssueViewModelFactoryProtocol {
    func detectIssues(in model: SwapIssueCheckParams, locale: Locale) -> [SwapSetupViewIssue] {
        [
            detectZeroBalance(in: model),
            detectInsufficientBalance(in: model),
            detectMinBalanceViolationOnReceive(in: model, locale: locale),
            detectNoLiquidity(in: model)
        ].compactMap { $0 }
    }
}
