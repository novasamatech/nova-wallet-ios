import Foundation
import NovaCrypto

enum NoSigningSupportType {
    case paritySigner
    case ledger
    case polkadotVault
    case proxy
    case multisig
}

enum NoSigningSupportError: Error {
    case notSupported(type: NoSigningSupportType)
}

final class NoSigningSupportWrapper: SigningWrapperProtocol {
    let type: NoSigningSupportType

    init(type: NoSigningSupportType) {
        self.type = type
    }

    func sign(_: Data, context _: ExtrinsicSigningContext) throws -> IRSignatureProtocol {
        throw NoSigningSupportError.notSupported(type: type)
    }
}
