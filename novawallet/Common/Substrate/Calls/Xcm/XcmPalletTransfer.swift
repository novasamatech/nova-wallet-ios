import Foundation
import SubstrateSdk

extension Xcm {
    struct PalletTransferCall: Codable {
        enum CodingKeys: String, CodingKey {
            case destination = "dest"
            case beneficiary
            case assets
            case feeAssetItem = "fee_asset_item"
            case weightLimit = "weight_limit"
        }

        let destination: XcmUni.VersionedLocation
        let beneficiary: XcmUni.VersionedLocation // must be set relatively to destination
        let assets: XcmUni.VersionedAssets
        @StringCodable var feeAssetItem: UInt32 // index of the fee asset in assets
        let weightLimit: Xcm.WeightLimit<JSON> // maximum weight for remote execution

        func runtimeCall(for path: CallCodingPath) -> RuntimeCall<PalletTransferCall> {
            RuntimeCall(moduleName: path.moduleName, callName: path.callName, args: self)
        }
    }

    static func limitedReserveTransferAssetsPath(for module: String) -> CallCodingPath {
        CallCodingPath(moduleName: module, callName: "limited_reserve_transfer_assets")
    }

    static func limitedTeleportAssetsPath(for module: String) -> CallCodingPath {
        CallCodingPath(moduleName: module, callName: "limited_teleport_assets")
    }

    static func transferAssetsPath(for module: String) -> CallCodingPath {
        CallCodingPath(moduleName: module, callName: "transfer_assets")
    }

    struct TransferAssetsUsingTypeAndThen: Codable {
        static let callName = "transfer_assets_using_type_and_then"

        enum CodingKeys: String, CodingKey {
            case destination = "dest"
            case assets
            case assetsTransferType = "assets_transfer_type"
            case remoteFeesId = "remote_fees_id"
            case feesTransferType = "fees_transfer_type"
            case customXcmOnDest = "custom_xcm_on_dest"
            case weightLimit = "weight_limit"
        }

        let destination: XcmUni.VersionedLocation
        let assets: XcmUni.VersionedAssets
        let assetsTransferType: TransferType
        let remoteFeesId: XcmUni.VersionedAssetId
        let feesTransferType: TransferType
        let customXcmOnDest: XcmUni.VersionedMessage
        let weightLimit: Xcm.WeightLimit<JSON> // maximum weight for remote execution

        func runtimeCall(for moduleName: String) -> RuntimeCall<Self> {
            RuntimeCall(
                moduleName: moduleName,
                callName: Self.callName,
                args: self
            )
        }
    }
}
