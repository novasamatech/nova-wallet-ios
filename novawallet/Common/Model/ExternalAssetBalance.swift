import Foundation
import BigInt
import RobinHood

struct ExternalAssetBalance: Equatable, Identifiable {
    enum BalanceType: String {
        case crowdloan
        case nominationPools
        case unknown

        init(rawType: String) {
            if let knownType = Self(rawValue: rawType) {
                self = knownType
            } else {
                self = .unknown
            }
        }
    }

    let identifier: String
    let chainAssetId: ChainAssetId
    let accountId: AccountId
    let amount: BigUInt
    let type: BalanceType
    let subtype: String?
    let param: String?
}
