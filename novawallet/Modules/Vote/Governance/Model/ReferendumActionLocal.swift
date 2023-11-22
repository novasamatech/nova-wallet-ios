import Foundation
import BigInt
import SubstrateSdk

struct ReferendumActionLocal {
    struct AmountSpendDetails {
        let amount: BigUInt
        let beneficiary: MultiAddress
    }

    enum Call<C> {
        case concrete(C)
        case tooLong

        var value: C? {
            switch self {
            case let .concrete(call):
                return call
            case .tooLong:
                return nil
            }
        }
    }

    let amountSpendDetailsList: [AmountSpendDetails]
    let call: Call<RuntimeCall<JSON>>?

    func spentAmount() -> BigUInt? {
        guard !amountSpendDetailsList.isEmpty else {
            return nil
        }

        return amountSpendDetailsList.reduce(BigUInt(0)) { $0 + $1.amount }
    }

    var beneficiary: MultiAddress? {
        amountSpendDetailsList.first?.beneficiary
    }
}
