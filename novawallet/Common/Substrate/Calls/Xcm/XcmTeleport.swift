import Foundation
import SubstrateSdk

extension Xcm {
    struct TeleportCall: Codable {
        // swiftlint:disable:next nesting
        enum CodingKeys: String, CodingKey {
            case destination = "dest"
            case beneficiary
            case assets
            case feeAssetItem = "fee_asset_item"
            case weightLimit = "weight_limit"
        }

        static let callName = "limited_teleport_assets"

        let destination: VersionedMultilocation
        let beneficiary: VersionedMultilocation // must be set relatively to destination
        let assets: VersionedMultiassets
        @StringCodable var feeAssetItem: UInt32 // index of the fee asset in assets
        let weightLimit: Xcm.WeightLimit // maximum weight for remote execution

        func runtimeCall(for module: String) -> RuntimeCall<TeleportCall> {
            RuntimeCall(moduleName: module, callName: Self.callName, args: self)
        }

        func codingPath(for module: String) -> CallCodingPath {
            CallCodingPath(moduleName: module, callName: Self.callName)
        }
    }
}
