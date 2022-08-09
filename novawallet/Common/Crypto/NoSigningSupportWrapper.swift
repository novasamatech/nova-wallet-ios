import Foundation
import IrohaCrypto

enum NoSigningSupportError: Error {
    case notSupported
}

final class NoSigningSupportWrapper: SigningWrapperProtocol {
    func sign(_: Data) throws -> IRSignatureProtocol {
        throw NoSigningSupportError.notSupported
    }
}
