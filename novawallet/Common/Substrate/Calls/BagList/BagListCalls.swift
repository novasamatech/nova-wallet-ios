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

    var runtimeCalls: [RuntimeCall<BagList.RebagCall>] {
        BagList.possibleModuleNames.map {
            RuntimeCall(moduleName: $0, callName: "rebag", args: self)
        }
    }

    var defaultRuntimeCall: RuntimeCall<BagList.RebagCall> {
        RuntimeCall(moduleName: BagList.defaultModuleName, callName: "rebag", args: self)
    }
}
