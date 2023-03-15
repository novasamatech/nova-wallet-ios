import Foundation
import SubstrateSdk
import BigInt

extension BagList {
    struct RebagCall: Codable {
        enum CodingKeys: String, CodingKey {
            case dislocated
        }

        var dislocated: MultiAddress
    }
}

extension BagList.RebagCall {
    var extrinsicIdentifier: String {
        dislocated.accountId?.toHexString() ?? ""
    }

    var runtimeCall: RuntimeCall<BagList.RebagCall> {
        RuntimeCall(moduleName: "VoterList", callName: "rebag", args: self)
    }
}
