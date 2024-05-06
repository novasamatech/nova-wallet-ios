import Foundation
import SubstrateSdk

/**
 *     Signed extension setup consists of the 2 parts:
 *      - provide signed extension class that contains parameters for the extrinsic's signed extra
 *      - provide coders to encode/decode signed extension's parameters part of signed extra
 */
protocol ExtrinsicSignedExtensionFactoryProtocol {
    func createExtensions() -> [ExtrinsicExtension]

    func createExtensions(payingFeeIn assetId: AssetConversionPallet.AssetId) -> [ExtrinsicExtension]

    func createCoders(for metadata: RuntimeMetadataProtocol) -> [ExtrinsicExtensionCoder]
}

final class ExtrinsicSignedExtensionFactory {}

extension ExtrinsicSignedExtensionFactory: ExtrinsicSignedExtensionFactoryProtocol {
    func createExtensions() -> [ExtrinsicExtension] {
        [
            ChargeAssetTxPayment()
        ]
    }

    func createExtensions(payingFeeIn assetId: AssetConversionPallet.AssetId) -> [ExtrinsicExtension] {
        [
            AssetConversionTxPayment(assetId: assetId)
        ]
    }

    func createCoders(for metadata: RuntimeMetadataProtocol) -> [ExtrinsicExtensionCoder] {
        DefaultSignedExtensionCoders.createDefaultCoders(for: metadata)
    }
}

enum DefaultSignedExtensionCoders {
    static func createDefaultCoders(for metadata: RuntimeMetadataProtocol) -> [ExtrinsicExtensionCoder] {
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
