import Foundation
import NovaCrypto

class MultisigSigningWrapper {}

extension MultisigSigningWrapper: SigningWrapperProtocol {
    func sign(
        _: Data,
        context _: ExtrinsicSigningContext
    ) throws -> any IRSignatureProtocol {
        // TODO: Implement
        throw NoKeysSigningWrapperError.watchOnly
    }
}
