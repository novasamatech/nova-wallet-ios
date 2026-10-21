import Foundation
import NovaCrypto
import Keystore_iOS

protocol SigningPreauthorizing: AnyObject {
    func preauthorize() throws
}

final class AuthorizeOnceSigningWrapper: BaseSigner, SigningWrapperProtocol {
    private let signer: SigningWrapper
    private let signaturesPerAuthorization: Int
    private let mutex = NSLock()

    private var authorizedSignaturesLeft = 0

    init(
        signer: SigningWrapper,
        signaturesPerAuthorization: Int,
        settingsManager: SettingsManagerProtocol
    ) {
        self.signer = signer
        self.signaturesPerAuthorization = signaturesPerAuthorization

        super.init(settingsManager: settingsManager)
    }

    override func sign(_ originalData: Data, context: ExtrinsicSigningContext) throws -> IRSignatureProtocol {
        if consumeAuthorizedSignature() {
            return try signData(originalData, context: context)
        }

        let signature = try super.sign(originalData, context: context)

        grantAuthorizedSignatures(count: signaturesPerAuthorization - 1)

        return signature
    }

    override func signData(_ data: Data, context: ExtrinsicSigningContext) throws -> IRSignatureProtocol {
        try signer.signData(data, context: context)
    }
}

private extension AuthorizeOnceSigningWrapper {
    func consumeAuthorizedSignature() -> Bool {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        guard authorizedSignaturesLeft > 0 else {
            return false
        }

        authorizedSignaturesLeft -= 1

        return true
    }

    func grantAuthorizedSignatures(count: Int) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        authorizedSignaturesLeft = max(count, 0)
    }
}

extension AuthorizeOnceSigningWrapper: SigningPreauthorizing {
    func preauthorize() throws {
        guard settingsManager.pinConfirmationEnabled == true else {
            return
        }

        let semaphore = DispatchSemaphore(value: 0)
        var isAuthorized = false

        DispatchQueue.main.async {
            self.authorize(animated: true, cancellable: true) { completed in
                isAuthorized = completed
                semaphore.signal()
            }
        }

        semaphore.wait()

        guard isAuthorized else {
            throw SigningWrapperError.pinCheckNotPassed
        }

        grantAuthorizedSignatures(count: signaturesPerAuthorization)
    }
}
