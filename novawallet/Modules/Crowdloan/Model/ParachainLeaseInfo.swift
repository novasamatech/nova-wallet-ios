import Foundation
import BigInt

struct ParachainLeaseInfo {
    let bidderKey: BidderKey
    let fundAccountId: AccountId
    let leasedAmount: BigUInt?
}

typealias ParachainLeaseInfoList = [ParachainLeaseInfo]
typealias ParachainLeaseInfoDict = [ParaId: ParachainLeaseInfo]

extension ParachainLeaseInfoList {
    func toMap() -> ParachainLeaseInfoDict {
        reduce(into: ParachainLeaseInfoDict()) { dict, info in
            dict[info.bidderKey] = info
        }
    }
}
