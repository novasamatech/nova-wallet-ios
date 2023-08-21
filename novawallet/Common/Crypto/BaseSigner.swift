import Foundation
import IrohaCrypto
import SoraKeystore

class BaseSigner: SignatureCreatorProtocol, AuthorizationPresentable {
    let settingsManager: SettingsManagerProtocol

    init(settingsManager: SettingsManagerProtocol) {
        self.settingsManager = settingsManager
    }

    func sign(_ originalData: Data) throws -> IRSignatureProtocol {
        if settingsManager.pinConfirmationEnabled == true {
            let signingResult = signAfterAutorization(originalData)
            switch signingResult {
            case let .success(signature):
                return signature
            case let .failure(error):
                throw error
            }
        } else {
            return try signData(originalData)
        }
    }

    private func signAfterAutorization(_ originalData: Data) -> Result<IRSignatureProtocol, Error> {
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
                        let sign = try self.signData(originalData)
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

    func signData(_: Data) throws -> IRSignatureProtocol {
        fatalError("Must be overriden by subsclass")
    }
}
