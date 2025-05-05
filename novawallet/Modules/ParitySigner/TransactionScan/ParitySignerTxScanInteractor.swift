import UIKit
import NovaCrypto
import SubstrateSdk

enum ParitySignerTxScanInteractorError: Error {
    case invalidSignaturePayload
    case invalidSignature
}

final class ParitySignerTxScanInteractor {
    weak var presenter: ParitySignerTxScanInteractorOutputProtocol?

    let signingData: Data
    let accountId: AccountId
    let params: ParitySignerConfirmationParams

    private var signaturePayload: Data?

    init(signingData: Data, params: ParitySignerConfirmationParams, accountId: AccountId) {
        self.signingData = signingData
        self.params = params
        self.accountId = accountId
    }

    private func getSignaturePayload() -> Data? {
        if let signaturePayload = signaturePayload {
            return signaturePayload
        } else {
            switch params.mode {
            case .extrinsic:
                signaturePayload = try? ExtrinsicSignatureConverter.convertParitySignerSignaturePayloadToRegular(
                    signingData
                )

                return signaturePayload
            case .rawBytes:
                signaturePayload = signingData

                return signaturePayload
            }
        }
    }

    private func getRawSignature(from scannedSignature: String) throws -> Data {
        let rawSignatureCandidate = try Data(hexString: scannedSignature)

        switch params.mode {
        case .extrinsic:
            // extrinsic signature also contains signature type as first byte
            return rawSignatureCandidate.dropFirst()
        case .rawBytes:
            return rawSignatureCandidate
        }
    }
}

extension ParitySignerTxScanInteractor: ParitySignerTxScanInteractorInputProtocol {
    func process(scannedSignature: String) {
        do {
            guard let signaturePayload = getSignaturePayload() else {
                throw ParitySignerTxScanInteractorError.invalidSignaturePayload
            }

            let rawSignatureCandidate = try getRawSignature(from: scannedSignature)
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
