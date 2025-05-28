import Foundation
import NovaCrypto

enum NoKeysSigningWrapperError: Error {
    case watchOnly
}

final class NoKeysSigningWrapper: SigningWrapperProtocol {
    func sign(_: Data, context _: ExtrinsicSigningContext) throws -> IRSignatureProtocol {
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

    var isSigningCancelled: Bool {
        isHardwareWalletSigningCancelled || isDelegatedSigningCancelled
    }

    var isSigningClosed: Bool {
        isDelegatedSigningClosed
    }

    var isHardwareWalletSigningCancelled: Bool {
        guard let hardwareWalletError = self as? HardwareSigningError else {
            return false
        }

        switch hardwareWalletError {
        case .signingCancelled:
            return true
        }
    }

    var isDelegatedSigningClosed: Bool {
        guard let delegatedSigningError = self as? DelegatedSigningWrapperError else {
            return false
        }

        switch delegatedSigningError {
        case .closed:
            return true
        default:
            return false
        }
    }

    var isDelegatedSigningCancelled: Bool {
        guard let delegatedSigningError = self as? DelegatedSigningWrapperError else {
            return false
        }

        switch delegatedSigningError {
        case .canceled:
            return true
        default:
            return false
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
