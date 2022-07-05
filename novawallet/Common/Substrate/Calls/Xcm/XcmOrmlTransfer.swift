import Foundation
import BigInt
import SubstrateSdk

extension Xcm {
    struct OrmlTransferCall: Codable {
        // swiftlint:disable:next nesting
        enum CodingKeys: String, CodingKey {
            case asset
            case destination = "dest"
            case destinationWeight = "dest_weight"
        }

        static let callName = "transfer_multiasset"

        let asset: VersionedMultiasset
        let destination: VersionedMultilocation

        // must be set as maximum between reserve and destination
        @StringCodable var destinationWeight: BigUInt

        func runtimeCall(for module: String) -> RuntimeCall<OrmlTransferCall> {
            RuntimeCall(moduleName: module, callName: Self.callName, args: self)
        }

        func codingPath(for module: String) -> CallCodingPath {
            CallCodingPath(moduleName: module, callName: Self.callName)
        }
    }
}
