import Foundation
import BigInt
import SubstrateSdk

struct ReferendumActionLocal {
    enum Asset: Equatable {
        case current
        case other(ChainAsset)
    }

    struct Amount {
        let value: BigUInt
        let asset: Asset
    }

    struct AmountSpendDetails {
        let benefiary: AccountId
        let amount: Amount
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

    func requestedAmount() -> Amount? {
        guard let fRequest = amountSpendDetailsList.first else {
            return nil
        }

        let isSameAsset = amountSpendDetailsList.allSatisfy { $0.amount.asset == fRequest.amount.asset }

        if isSameAsset {
            let totalAmount = amountSpendDetailsList.reduce(BigUInt(0)) { $0 + $1.amount.value }

            return .init(value: totalAmount, asset: fRequest.amount.asset)
        } else {
            return fRequest.amount
        }
    }

    var beneficiary: AccountId? {
        amountSpendDetailsList.first?.benefiary
    }
}
