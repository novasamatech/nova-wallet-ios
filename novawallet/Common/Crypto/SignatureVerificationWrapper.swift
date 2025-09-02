import Foundation
import NovaCrypto

protocol SignatureVerificationWrapperProtocol {
    func verify(
        rawSignature: Data,
        originalData: Data,
        rawPublicKey: Data,
        cryptoType: MultiassetCryptoType
    ) throws -> IRSignatureProtocol?
}

final class SignatureVerificationWrapper: SignatureVerificationWrapperProtocol {
    private func verifySr25519(
        rawSignature: Data,
        originalData: Data,
        rawPublicKey: Data
    ) throws -> IRSignatureProtocol? {
        let signature = try SNSignature(rawData: rawSignature)
        let verifier = SNSignatureVerifier()
        let publicKey = try SNPublicKey(rawData: rawPublicKey)

        if verifier.verify(signature, forOriginalData: originalData, using: publicKey) {
            return signature
        } else {
            return nil
        }
    }

    private func verifyEd25519(
        rawSignature: Data,
        originalData: Data,
        rawPublicKey: Data
    ) throws -> IRSignatureProtocol? {
        let signature = try EDSignature(rawData: rawSignature)
        let verifier = EDSignatureVerifier()
        let publicKey = try EDPublicKey(rawData: rawPublicKey)

        if verifier.verify(signature, forOriginalData: originalData, usingPublicKey: publicKey) {
            return signature
        } else {
            return nil
        }
    }

    private func verifyEcdsa(
        rawSignature: Data,
        hashedOriginalData: Data,
        rawPublicKey: Data
    ) throws -> IRSignatureProtocol? {
        let signature = try SECSignature(rawData: rawSignature)
        let verifier = SECSignatureVerifier()
        let publicKey = try SECPublicKey(rawData: rawPublicKey)

        if verifier.verify(signature, forOriginalData: hashedOriginalData, usingPublicKey: publicKey) {
            return signature
        } else {
            return nil
        }
    }

    private func verifySubstrateEcdsa(
        rawSignature: Data,
        originalData: Data,
        rawPublicKey: Data
    ) throws -> IRSignatureProtocol? {
        let hashedData = try originalData.blake2b32()

        return try verifyEcdsa(
            rawSignature: rawSignature,
            hashedOriginalData: hashedData,
            rawPublicKey: rawPublicKey
        )
    }

    private func verifyEthereumEcdsa(
        rawSignature: Data,
        originalData: Data,
        rawPublicKey: Data
    ) throws -> IRSignatureProtocol? {
        let hashedData = try originalData.keccak256()

        return try verifyEcdsa(
            rawSignature: rawSignature,
            hashedOriginalData: hashedData,
            rawPublicKey: rawPublicKey
        )
    }

    func verify(
        rawSignature: Data,
        originalData: Data,
        rawPublicKey: Data,
        cryptoType: MultiassetCryptoType
    ) throws -> IRSignatureProtocol? {
        switch cryptoType {
        case .sr25519:
            return try verifySr25519(
                rawSignature: rawSignature,
                originalData: originalData,
                rawPublicKey: rawPublicKey
            )
        case .ed25519:
            return try verifyEd25519(
                rawSignature: rawSignature,
                originalData: originalData,
                rawPublicKey: rawPublicKey
            )
        case .substrateEcdsa:
            return try verifySubstrateEcdsa(
                rawSignature: rawSignature,
                originalData: originalData,
                rawPublicKey: rawPublicKey
            )
        case .ethereumEcdsa:
            return try verifyEthereumEcdsa(
                rawSignature: rawSignature,
                originalData: originalData,
                rawPublicKey: rawPublicKey
            )
        }
    }
}
