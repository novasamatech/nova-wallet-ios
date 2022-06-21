import Foundation
import SubstrateSdk
import BigInt

extension Xcm {
    struct ExecuteCall: Codable {
        enum CodingKeys: String, CodingKey {
            case message
            case maxWeight = "max_weight"
        }

        let message: Xcm.Message
        @StringCodable var maxWeight: BigUInt

        var runtimeCall: RuntimeCall<ExecuteCall> {
            RuntimeCall(moduleName: "PolkadotXcm", callName: "execute", args: self)
        }
    }
}
