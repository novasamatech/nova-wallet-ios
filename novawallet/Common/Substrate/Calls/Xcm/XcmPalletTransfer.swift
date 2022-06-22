import Foundation
import SubstrateSdk

extension Xcm {
    struct PalletTransferCall: Codable {
        // swiftlint:disable:next nesting
        enum CodingKeys: String, CodingKey {
            case destination = "dest"
            case beneficiary
            case assets
            case feeAssetItem = "fee_asset_item"
            case weightLimit = "weight_limit"
        }

        let destination: VersionedMultilocation
        let beneficiary: VersionedMultilocation // must be set relatively to destination
        let assets: VersionedMultiassets
        @StringCodable var feeAssetItem: UInt32 // index of the fee asset in assets
        let weightLimit: Xcm.WeightLimit // maximum weight for remote execution

        func runtimeCall(for module: String) -> RuntimeCall<PalletTransferCall> {
            RuntimeCall(moduleName: module, callName: "limited_reserve_transfer_assets", args: self)
        }
    }
}
