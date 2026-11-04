import Foundation
import NovaCrypto
import Keystore_iOS

class BaseSigner: SignatureCreatorProtocol, AuthorizationPresentable {
    let settingsManager: SettingsManagerProtocol

    init(settingsManager: SettingsManagerProtocol) {
        self.settingsManager = settingsManager
    }

    func sign(_ originalData: Data, context: ExtrinsicSigningContext) throws -> IRSignatureProtocol {
        if settingsManager.pinConfirmationEnabled == true {
            return try authorizeSynchronously { signer in
                try signer.signData(originalData, context: context)
            }
        } else {
            return try signData(originalData, context: context)
        }
    }

    final func authorizeSynchronously<T>(then action: @escaping (BaseSigner) throws -> T) throws -> T {
        let semaphore = DispatchSemaphore(value: 0)
        var result: Result<T, Error>?

        DispatchQueue.main.async {
            self.authorize(animated: true, cancellable: true) { [weak self] completed in
                defer {
                    semaphore.signal()
                }
                guard let self = self else {
                    return
                }
                if completed {
                    result = Result { try action(self) }
                }
            }
        }

        semaphore.wait()

        return try (result ?? .failure(SigningWrapperError.pinCheckNotPassed)).get()
    }

    func signData(_: Data, context _: ExtrinsicSigningContext) throws -> IRSignatureProtocol {
        fatalError("Must be overriden by subsclass")
    }
}
