import Foundation
import IrohaCrypto

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
        isHardwareWalletSigningCancelled || isProxySigningCancelled
    }

    var isSigningClosed: Bool {
        isProxySigningClosed
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

    var isProxySigningClosed: Bool {
        guard let proxySigningError = self as? ProxySigningWrapperError else {
            return false
        }

        switch proxySigningError {
        case .closed:
            return true
        default:
            return false
        }
    }

    var isProxySigningCancelled: Bool {
        guard let proxySigningError = self as? ProxySigningWrapperError else {
            return false
        }

        switch proxySigningError {
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
