import Foundation

protocol GiftSetupIssueViewModelFactoryProtocol: AnyObject {
    func detectIssues(
        in model: GiftSetupIssueCheckParams,
        locale: Locale
    ) -> [GiftSetupViewIssue]
}

final class GiftSetupIssueViewModelFactory {
    let balanceViewModelFactoryFacade: BalanceViewModelFactoryFacadeProtocol

    init(balanceViewModelFactoryFacade: BalanceViewModelFactoryFacadeProtocol) {
        self.balanceViewModelFactoryFacade = balanceViewModelFactoryFacade
    }

    func detectInsufficientBalance(
        in model: GiftSetupIssueCheckParams,
        locale: Locale
    ) -> GiftSetupViewIssue? {
        guard
            let enteredAmount = model.enteredAmount,
            enteredAmount > 0
        else {
            return nil
        }

        let assetDisplayInfo = model.chainAsset.assetDisplayInfo
        let balance = model.assetBalance?.transferable.decimal(assetInfo: assetDisplayInfo) ?? 0
        let fee = model.fee?.amount.decimal(assetInfo: assetDisplayInfo) ?? 0

        if enteredAmount + fee > balance {
            let localizedStrings = R.string(
                preferredLanguages: locale.rLanguages
            ).localizable

            let issueText = localizedStrings.giftValidationNotEnoughTokens()
            let actionText = localizedStrings.transferSetupEnterAnotherAmount()

            let attributes = GiftSetupViewIssue.IssueAttributes(
                issueText: issueText,
                actionText: actionText,
                getTokensButtonVisible: true
            )
            return .insufficientBalance(attributes)
        } else {
            return nil
        }
    }

    func detectGiftEdViolation(
        in model: GiftSetupIssueCheckParams,
        locale: Locale
    ) -> GiftSetupViewIssue? {
        guard
            let enteredAmount = model.enteredAmount,
            enteredAmount > 0,
            let minGiftAmount = model.assetExistence?.minBalance.decimal(
                precision: model.chainAsset.asset.precision
            )
        else {
            return nil
        }

        let assetDisplayInfo = model.chainAsset.assetDisplayInfo

        if enteredAmount < minGiftAmount {
            let formattedMinGiftAmount = balanceViewModelFactoryFacade.amountFromValue(
                targetAssetInfo: assetDisplayInfo,
                value: minGiftAmount
            ).value(for: locale)

            let localizedStrings = R.string(
                preferredLanguages: locale.rLanguages
            ).localizable

            let issueText = localizedStrings.giftValidationMinimalGiftAmount(formattedMinGiftAmount)
            let actionText = localizedStrings.transferSetupEnterAnotherAmount()

            let attributes = GiftSetupViewIssue.IssueAttributes(
                issueText: issueText,
                actionText: actionText,
                getTokensButtonVisible: false
            )
            return .minAmountViolation(attributes)
        } else {
            return nil
        }
    }
}

extension GiftSetupIssueViewModelFactory: GiftSetupIssueViewModelFactoryProtocol {
    func detectIssues(
        in model: GiftSetupIssueCheckParams,
        locale: Locale
    ) -> [GiftSetupViewIssue] {
        [
            detectInsufficientBalance(in: model, locale: locale),
            detectGiftEdViolation(in: model, locale: locale)
        ].compactMap { $0 }
    }
}
