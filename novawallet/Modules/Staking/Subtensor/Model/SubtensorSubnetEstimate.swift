import BigInt
import Foundation

enum SubtensorSubnetEstimate {
    static func hold(amountTao: Balance, spot: Balance) -> Balance? {
        guard spot > 0 else {
            return nil
        }

        let novaFee = SubtensorNovaFeeConstants.rate.asShareOfGross.mul(value: amountTao)

        return (amountTao - novaFee) * SubtensorStakingPallet.alphaPriceScale / spot
    }
}
