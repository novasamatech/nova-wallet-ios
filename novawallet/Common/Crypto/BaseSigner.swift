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
            let signingResult = signAfterAutorization(originalData, context: context)
            switch signingResult {
            case let .success(signature):
                return signature
            case let .failure(error):
                throw error
            }
        } else {
            return try signData(originalData, context: context)
        }
    }

    private func signAfterAutorization(
        _ originalData: Data,
        context: ExtrinsicSigningContext
    ) -> Result<IRSignatureProtocol, Error> {
        let semaphore = DispatchSemaphore(value: 0)
        var signResult: Result<IRSignatureProtocol, Error>?

        DispatchQueue.main.async {
            self.authorize(animated: true, cancellable: true) { [weak self] completed in
                defer {
                    semaphore.signal()
                }
                guard let self = self else {
                    return
                }
                if completed {
                    do {
                        let sign = try self.signData(originalData, context: context)
                        signResult = .success(sign)
                    } catch {
                        signResult = .failure(error)
                    }
                }
            }
        }

        semaphore.wait()

        return signResult ?? .failure(SigningWrapperError.pinCheckNotPassed)
    }

    func signData(_: Data, context _: ExtrinsicSigningContext) throws -> IRSignatureProtocol {
        fatalError("Must be overriden by subsclass")
    }
}
