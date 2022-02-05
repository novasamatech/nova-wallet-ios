import Foundation
import SubstrateSdk

enum DefaultExtrinsicExtension {
    static var extensions: [ExtrinsicExtension] {
        [
            ChargeAssetTxPayment()
        ]
    }

    static var coders: [ExtrinsicExtensionCoder] {
        [
            DefaultExtrinsicExtensionCoder(
                name: ChargeAssetTxPayment.name,
                extraType: "pallet_asset_tx_payment.ChargeAssetTxPayment"
            )
        ]
    }
}
