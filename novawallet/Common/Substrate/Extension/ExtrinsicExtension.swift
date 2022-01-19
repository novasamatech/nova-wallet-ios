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
            ChargeAssetTxPaymentCoder()
        ]
    }
}
