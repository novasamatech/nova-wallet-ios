import Foundation
import SubstrateSdk

enum DefaultExtrinsicExtension {
    static func extensions() -> [ExtrinsicExtension] {
        [
            ChargeAssetTxPayment()
        ]
    }

    static func extensions(payingFeeIn assetId: UInt32) -> [ExtrinsicExtension] {
        [
            ChargeAssetTxPayment(assetId: assetId)
        ]
    }

    static func getCoders(for metadata: RuntimeMetadataProtocol) -> [ExtrinsicExtensionCoder] {
        let extensionName = ChargeAssetTxPayment.name

        let extraType = metadata.getSignedExtensionType(for: extensionName)

        return [
            DefaultExtrinsicExtensionCoder(
                name: ChargeAssetTxPayment.name,
                extraType: extraType ?? "pallet_asset_tx_payment.ChargeAssetTxPayment"
            )
        ]
    }
}
