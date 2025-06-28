import Foundation
import SubstrateSdk

/**
 *     Signed extension setup consists of the 2 parts:
 *      - provide signed extension class that contains parameters for the extrinsic's signed extra
 *      - provide coders to encode/decode signed extension's parameters part of signed extra
 */
protocol ExtrinsicSignedExtensionFactoryProtocol {
    func createExtensions() -> [TransactionExtending]

    func createExtensions(payingFeeIn assetId: AssetConversionPallet.AssetId) -> [TransactionExtending]

    func createCoders(for metadata: RuntimeMetadataProtocol) -> [TransactionExtensionCoding]
}

final class ExtrinsicSignedExtensionFactory {}

extension ExtrinsicSignedExtensionFactory: ExtrinsicSignedExtensionFactoryProtocol {
    func createExtensions() -> [TransactionExtending] {
        [
            TransactionExtension.ChargeAssetTxPayment(),
            AvailSignedExtension.CheckAppId(appId: 0)
        ]
    }

    func createExtensions(payingFeeIn assetId: AssetConversionPallet.AssetId) -> [TransactionExtending] {
        [
            AssetConversionTxPayment(assetId: assetId)
        ]
    }

    func createCoders(for metadata: RuntimeMetadataProtocol) -> [TransactionExtensionCoding] {
        let baseCoders = DefaultSignedExtensionCoders.createDefaultCoders(for: metadata)
        let availCoders = AvailSignedExtensionCoders.getCoders(for: metadata)

        return baseCoders + availCoders
    }
}

enum DefaultSignedExtensionCoders {
    static func createDefaultCoders(for metadata: RuntimeMetadataProtocol) -> [TransactionExtensionCoding] {
        let extensionId = Extrinsic.TransactionExtensionId.assetTxPayment

        let extraType = metadata.getSignedExtensionType(for: extensionId)

        return [
            DefaultTransactionExtensionCoder(
                txExtensionId: extensionId,
                extensionExplicitType: extraType ?? "pallet_asset_tx_payment.ChargeAssetTxPayment"
            )
        ]
    }
}
