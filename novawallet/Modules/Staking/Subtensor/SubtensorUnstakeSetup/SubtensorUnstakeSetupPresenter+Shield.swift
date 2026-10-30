import Foundation

extension SubtensorUnstakeSetupPresenter: SubtensorShieldQuoteHandling {
    var transferable: Balance? { balance?.transferable }
    var shieldWalletType: MetaAccountModelType { selectedAccount.chainAccount.type }
    var shieldInteractor: SubtensorBaseInteractorInputProtocol { interactor }

    func applyShieldQuoteChange() {
        provideViewModel()
    }
}

extension SubtensorUnstakeSetupPresenter {
    func refreshShieldQuote(for operation: SubtensorOperation?, plan: SubtensorUnstakePlan?) {
        let inputs = SubtensorUnstakeShieldQuoteInputs(plan: plan, transferable: transferable)

        guard let operation, inputs != shieldQuoteInputs else {
            return
        }

        shieldQuoteInputs = inputs
        requestShieldQuote(for: operation)
    }
}

struct SubtensorUnstakeShieldQuoteInputs: Equatable {
    let plan: SubtensorUnstakePlan?
    let transferable: Balance?
}
