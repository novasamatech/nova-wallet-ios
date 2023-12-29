import Foundation

enum ExtrinsicSigningContext {
    struct Substrate {
        let senderResolution: ExtrinsicSenderResolution
        let chainFormat: ChainFormat
        let cryptoType: MultiassetCryptoType
    }

    case substrateExtrinsic(Substrate)
    case evmTransaction
    case rawBytes
}
