import Foundation

struct SubtensorShieldEligibilityInput {
    let walletType: MetaAccountModelType
    let quote: SubtensorShieldQuote?
    let transferable: Balance?
    let existentialDeposit: Balance?
}

enum SubtensorShieldEligibility {
    static func supports(operation: SubtensorOperation) -> Bool {
        switch operation {
        case let .subnetBuy(_, netuid, _, _, _),
             let .subnetSell(_, netuid, _, _, _, _),
             let .subnetSellGroup(_, _, netuid, _, _, _):
            netuid != SubtensorPallet.rootNetuid
        case .rootStake, .rootUnstake, .rootUnstakeGroup, .rootClaim:
            false
        }
    }

    static func supports(walletType: MetaAccountModelType) -> Bool {
        walletType == .secrets
    }

    static func canPayCarrierFee(
        _ carrierFee: Balance,
        transferable: Balance,
        existentialDeposit: Balance
    ) -> Bool {
        SubtensorAmountPolicy.paysFeeFromFreeBalance(
            transferable: transferable,
            networkFee: carrierFee,
            existentialDeposit: existentialDeposit
        )
    }

    static func isEligible(_ input: SubtensorShieldEligibilityInput) -> Bool {
        guard
            let quote = input.quote,
            let transferable = input.transferable,
            let existentialDeposit = input.existentialDeposit else {
            return false
        }

        return supports(operation: quote.operation) &&
            supports(walletType: input.walletType) &&
            canPayCarrierFee(
                quote.carrierFee.amount,
                transferable: transferable,
                existentialDeposit: existentialDeposit
            )
    }
}
