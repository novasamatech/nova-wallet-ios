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
        switch verificationModel.cryptoType {
        case .sr25519, .ed25519:
            signaturePayload = try? ExtrinsicSignatureConverter.convertParitySignerSignaturePayloadToRegular(
                signingData
            )

            return signaturePayload
        case .ethereumEcdsa, .substrateEcdsa:
            return signingData
        }
    }

    private func getSignaturePayload() -> Data? {
        if let signaturePayload = signaturePayload {
            return signaturePayload
        } else {
            switch params.mode {
            case .extrinsic:
                return getExtrinsicSignaturePayload()
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
    func process(scannedSignature _: String) {
        do {
            guard let signaturePayload = getSignaturePayload() else {
                throw ParitySignerTxScanInteractorError.invalidSignaturePayload
            }

            let optSignature = try verificationWrapper.verify(
                rawSignature: signaturePayload,
                originalData: signingData,
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
