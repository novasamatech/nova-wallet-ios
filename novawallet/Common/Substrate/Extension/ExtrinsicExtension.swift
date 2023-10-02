import Foundation
import SubstrateSdk

enum DefaultExtrinsicExtension {
    static var extensions: [ExtrinsicExtension] {
        [
            ChargeAssetTxPayment()
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
