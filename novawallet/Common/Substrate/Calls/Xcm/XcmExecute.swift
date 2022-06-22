import Foundation
import SubstrateSdk
import BigInt

extension Xcm {
    struct ExecuteCall: Codable {
        // swiftlint:disable:next nesting
        enum CodingKeys: String, CodingKey {
            case message
            case maxWeight = "max_weight"
        }

        let message: Xcm.Message
        @StringCodable var maxWeight: BigUInt

        func runtimeCall(for moduleName: String) -> RuntimeCall<ExecuteCall> {
            RuntimeCall(moduleName: moduleName, callName: "execute", args: self)
        }

        static var possibleModuleNames: [String] { ["XcmPallet", "PolkadotXcm"] }
    }
}
