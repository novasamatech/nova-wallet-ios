import Foundation
import IrohaCrypto

enum NoKeysSigningWrapperError: Error {
    case watchOnly
}

final class NoKeysSigningWrapper: SigningWrapperProtocol {
    func sign(_: Data) throws -> IRSignatureProtocol {
        throw NoKeysSigningWrapperError.watchOnly
    }
}

extension Error {
    var isWatchOnlySigning: Bool {
        guard let noKeysError = self as? NoKeysSigningWrapperError else {
            return false
        }

        switch noKeysError {
        case .watchOnly:
            return true
        }
    }

    var isNotSupportedByParitySigner: Bool {
        guard let notSupportedError = self as? NoSigningSupportError else {
            return false
        }

        switch notSupportedError {
        case .notSupported:
            return true
        }
    }
}
