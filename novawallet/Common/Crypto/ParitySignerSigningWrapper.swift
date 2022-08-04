import Foundation
import IrohaCrypto

final class ParitySignerSigningWrapper {}

extension ParitySignerSigningWrapper: SigningWrapperProtocol {
    func sign(_: Data) throws -> IRSignatureProtocol {
        // TODO: Add implementation in separate task
        throw CommonError.undefined
    }
}
