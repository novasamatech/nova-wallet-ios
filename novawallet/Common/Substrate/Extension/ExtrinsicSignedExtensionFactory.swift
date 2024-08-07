import Foundation
import SubstrateSdk

/**
 *     Signed extension setup consists of the 2 parts:
 *      - provide signed extension class that contains parameters for the extrinsic's signed extra
 *      - provide coders to encode/decode signed extension's parameters part of signed extra
 */
protocol ExtrinsicSignedExtensionFactoryProtocol {
    func createExtensions() -> [ExtrinsicSignedExtending]

    func createExtensions(payingFeeIn assetId: AssetConversionPallet.AssetId) -> [ExtrinsicSignedExtending]

    func createCoders(for metadata: RuntimeMetadataProtocol) -> [ExtrinsicSignedExtensionCoding]
}

final class ExtrinsicSignedExtensionFactory {}

extension ExtrinsicSignedExtensionFactory: ExtrinsicSignedExtensionFactoryProtocol {
    func createExtensions() -> [ExtrinsicSignedExtending] {
        [
            ExtrinsicSignedExtension.ChargeAssetTxPayment(),
            AvailSignedExtension.CheckAppId(appId: 0)
        ]
    }

    func createExtensions(payingFeeIn assetId: AssetConversionPallet.AssetId) -> [ExtrinsicSignedExtending] {
        [
            AssetConversionTxPayment(assetId: assetId)
        ]
    }

    func createCoders(for metadata: RuntimeMetadataProtocol) -> [ExtrinsicSignedExtensionCoding] {
        let baseCoders = DefaultSignedExtensionCoders.createDefaultCoders(for: metadata)
        let availCoders = AvailSignedExtensionCoders.getCoders(for: metadata)

        return baseCoders + availCoders
    }
}

enum DefaultSignedExtensionCoders {
    static func createDefaultCoders(for metadata: RuntimeMetadataProtocol) -> [ExtrinsicSignedExtensionCoding] {
        let extensionId = Extrinsic.SignedExtensionId.assetTxPayment

        let extraType = metadata.getSignedExtensionType(for: extensionId)

        return [
            DefaultExtrinsicSignedExtensionCoder(
                signedExtensionId: extensionId,
                extraType: extraType ?? "pallet_asset_tx_payment.ChargeAssetTxPayment"
            )
        ]
    }
}
