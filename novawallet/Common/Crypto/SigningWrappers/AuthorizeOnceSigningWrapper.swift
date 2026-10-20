import Foundation
import NovaCrypto
import Keystore_iOS

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

        grantAuthorizedSignatures()

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

    func grantAuthorizedSignatures() {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        authorizedSignaturesLeft = max(signaturesPerAuthorization - 1, 0)
    }
}
