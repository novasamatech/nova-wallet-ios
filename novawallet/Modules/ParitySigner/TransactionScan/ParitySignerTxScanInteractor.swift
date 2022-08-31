import UIKit
import IrohaCrypto
import SubstrateSdk

enum ParitySignerTxScanInteractorError: Error {
    case invalidSignaturePayload
    case invalidSignature
}

final class ParitySignerTxScanInteractor {
    weak var presenter: ParitySignerTxScanInteractorOutputProtocol?

    let signingData: Data
    let accountId: AccountId

    private var signaturePayload: Data?

    init(signingData: Data, accountId: AccountId) {
        self.signingData = signingData
        self.accountId = accountId
    }

    private func getSignaturePayload() -> Data? {
        if let signaturePayload = signaturePayload {
            return signaturePayload
        } else {
            signaturePayload = try? ExtrinsicSignatureConverter.convertParitySignerSignaturePayloadToRegular(
                signingData
            )

            return signaturePayload
        }
    }
}

extension ParitySignerTxScanInteractor: ParitySignerTxScanInteractorInputProtocol {
    func process(scannedSignature: String) {
        do {
            guard let signaturePayload = getSignaturePayload() else {
                throw ParitySignerTxScanInteractorError.invalidSignaturePayload
            }

            let rawSignatureCandidate = try Data(hexString: scannedSignature).dropFirst()
            let signatureCandidate = try SNSignature(rawData: rawSignatureCandidate)
            let publicKey = try SNPublicKey(rawData: accountId)
            let verifier = SNSignatureVerifier()

            if verifier.verify(signatureCandidate, forOriginalData: signaturePayload, using: publicKey) {
                presenter?.didReceiveSignature(signatureCandidate)
            } else {
                presenter?.didReceiveError(ParitySignerTxScanInteractorError.invalidSignature)
            }
        } catch {
            presenter?.didReceiveError(error)
        }
    }
}
