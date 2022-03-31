import Foundation
import BigInt

struct ParachainLeaseInfo {
    let param: LeaseParam
    let fundAccountId: AccountId
    let leasedAmount: BigUInt?
}

typealias ParachainLeaseInfoList = [ParachainLeaseInfo]
typealias ParachainLeaseInfoDict = [ParaId: ParachainLeaseInfo]

extension ParachainLeaseInfoList {
    func toMap() -> ParachainLeaseInfoDict {
        reduce(into: ParachainLeaseInfoDict()) { dict, info in
            dict[info.param.paraId] = info
        }
    }
}
