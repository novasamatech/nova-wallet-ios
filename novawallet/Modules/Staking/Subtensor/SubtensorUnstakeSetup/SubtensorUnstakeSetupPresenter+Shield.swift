import Foundation

extension SubtensorUnstakeSetupPresenter {
    var eligibleShieldQuote: SubtensorShieldQuote? {
        let input = SubtensorShieldEligibilityInput(
            walletType: selectedAccount.chainAccount.type,
            quote: shieldQuote,
            transferable: balance?.transferable,
            existentialDeposit: existentialDeposit
        )

        return SubtensorShieldEligibility.isEligible(input) ? shieldQuote : nil
    }

    var networkFee: ExtrinsicFeeProtocol? {
        guard isShieldQuoteResolved else {
            return nil
        }

        return eligibleShieldQuote?.totalFee ?? fee
    }

    func resetShieldQuote() {
        shieldQuote = nil
        isShieldQuoteResolved = false
        shieldQuoteInputs = nil
    }

    func refreshShieldQuote(for operation: SubtensorOperation?, plan: SubtensorUnstakePlan?) {
        let inputs = SubtensorUnstakeShieldQuoteInputs(plan: plan, transferable: balance?.transferable)

        guard let operation, inputs != shieldQuoteInputs else {
            return
        }

        shieldQuoteInputs = inputs
        shieldQuoteOperation = operation
        interactor.estimateShieldQuote(for: operation)
    }

    func retryUnresolvedShieldQuote() {
        guard !isShieldQuoteResolved, let shieldQuoteOperation else {
            return
        }

        interactor.estimateShieldQuote(for: shieldQuoteOperation)
    }
}

struct SubtensorUnstakeShieldQuoteInputs: Equatable {
    let plan: SubtensorUnstakePlan?
    let transferable: Balance?
}
