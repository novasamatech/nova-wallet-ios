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

    var notSupportedSignerType: NoSigningSupportType? {
        guard let notSupportedError = self as? NoSigningSupportError else {
            return nil
        }

        switch notSupportedError {
        case let .notSupported(type):
            return type
        }
    }
}
