import BigInt
import Foundation

struct SubtensorAlphaPrices: Equatable {
    let catalogue: SubtensorSubnetCatalogue?
    let taoPerAlpha: [UInt16: Balance]

    func taoValue(of alpha: Balance, netuid: UInt16) -> Balance? {
        guard let price = taoPerAlpha[netuid], price > 0 else {
            return nil
        }

        return alpha * price / SubtensorStakingPallet.alphaPriceScale
    }
}
