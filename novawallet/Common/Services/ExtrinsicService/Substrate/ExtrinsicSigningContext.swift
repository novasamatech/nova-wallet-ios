import Foundation
import SubstrateSdk

enum ExtrinsicSigningContext {
    struct Substrate {
        let senderResolution: ExtrinsicSenderResolution
        let extrinsicMemo: ExtrinsicBuilderMemoProtocol
    }

    case substrateExtrinsic(Substrate)
    case evmTransaction
    case rawBytes

    var substrateCryptoType: MultiassetCryptoType? {
        switch self {
        case let .substrateExtrinsic(substrate):
            return substrate.senderResolution.account.cryptoType
        case .evmTransaction, .rawBytes:
            return nil
        }
    }
}
