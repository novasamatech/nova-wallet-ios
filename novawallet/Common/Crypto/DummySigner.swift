import Foundation
import NovaCrypto

enum DummySigningType {
    case sr25519(secretKeyData: Data, publicKeyData: Data)
    case ed25519(seed: Data)
    case ecdsa(seed: Data)
}

final class DummySigner: SigningWrapperProtocol {
    let type: DummySigningType

    init(cryptoType: MultiassetCryptoType, seed: Data = Data(repeating: 1, count: 32)) throws {
        switch cryptoType {
        case .sr25519:
            let keypair = try SNKeyFactory().createKeypair(fromSeed: seed)
            type = .sr25519(
                secretKeyData: keypair.privateKey().rawData(),
                publicKeyData: keypair.publicKey().rawData()
            )
        case .ed25519:
            type = .ed25519(seed: seed)
        case .substrateEcdsa, .ethereumEcdsa:
            type = .ecdsa(seed: seed)
        }
    }

    func sign(_ originalData: Data, context _: ExtrinsicSigningContext) throws -> IRSignatureProtocol {
        switch type {
        case let .sr25519(secretKeyData, publicKeyData):
            return try signSr25519(
                originalData,
                secretKeyData: secretKeyData,
                publicKeyData: publicKeyData
            )
        case let .ed25519(seed):
            return try signEd25519(originalData, secretKey: seed)
        case let .ecdsa(seed):
            return try signEcdsa(originalData, secretKey: seed)
        }
    }
}
