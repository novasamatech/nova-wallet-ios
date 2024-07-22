import Foundation
import SubstrateSdk

extension NominationPools {
    struct MigrateCall: Codable {
        enum CodingKeys: String, CodingKey {
            case memberAccount = "member_account"
        }

        let memberAccount: MultiAddress

        static var codingPath: CallCodingPath {
            .init(moduleName: NominationPools.module, callName: "migrate_delegation")
        }

        func runtimeCall() -> RuntimeCall<Self> {
            let codingPath = Self.codingPath
            return RuntimeCall(moduleName: codingPath.moduleName, callName: codingPath.callName, args: self)
        }
    }
}
