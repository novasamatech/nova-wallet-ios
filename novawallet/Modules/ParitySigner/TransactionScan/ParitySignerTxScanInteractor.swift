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
    let params: ParitySignerConfirmationParams
    let verificationModel: ParitySignerSignatureVerificationModel
    let verificationWrapper: SignatureVerificationWrapperProtocol

    private var signaturePayload: Data?

    init(
        signingData: Data,
        params: ParitySignerConfirmationParams,
        verificationModel: ParitySignerSignatureVerificationModel,
        verificationWrapper: SignatureVerificationWrapperProtocol
    ) {
        self.signingData = signingData
        self.params = params
        self.verificationModel = verificationModel
        self.verificationWrapper = verificationWrapper
    }

    private func getExtrinsicSignaturePayload() -> Data? {
        let shouldConvertToRegular = switch verificationModel.cryptoType {
        case .sr25519, .ed25519:
            true
        case .substrateEcdsa, .ethereumEcdsa:
            false
        }

        return try? ParitySignerSignatureConverter.convertParitySignerSignaturePayloadToRegular(
            signingData,
            shouldConvertToRegular: shouldConvertToRegular
        )
    }

    private func getSignaturePayload() -> Data? {
        if let signaturePayload = signaturePayload {
            return signaturePayload
        }

        signaturePayload = switch params.mode {
        case .extrinsic:
            getExtrinsicSignaturePayload()
        case .rawBytes:
            signingData
        }

        return signaturePayload
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

            let rawSignature = try getRawSignature(from: scannedSignature)

            let optSignature = try verificationWrapper.verify(
                rawSignature: rawSignature,
                originalData: signaturePayload,
                rawPublicKey: verificationModel.publicKey,
                cryptoType: verificationModel.cryptoType
            )

            if let signatureCandidate = optSignature {
                presenter?.didReceiveSignature(signatureCandidate)
            } else {
                presenter?.didReceiveError(ParitySignerTxScanInteractorError.invalidSignature)
            }
        } catch {
            presenter?.didReceiveError(error)
        }
    }
}
