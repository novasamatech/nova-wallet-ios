import Foundation
import NovaCrypto
import CryptoKit

enum SecureSessionManagerError: Error {
    case sessionNotStarted
}

final class SecureSessionManager {
    private var currentPrivateKey: P256.KeyAgreement.PrivateKey?
    let sharedSecretKeySize: Int

    init(sharedSecretKeySize: Int = 32) {
        self.sharedSecretKeySize = sharedSecretKeySize
    }
}

extension SecureSessionManager: SecureSessionManaging {
    func startSession() throws -> SecureSession.PublicKey {
        let privateKey = P256.KeyAgreement.PrivateKey()

        currentPrivateKey = privateKey

        return privateKey.publicKey.rawRepresentation
    }

    func deriveCryptor(peerPubKey: SecureSession.PublicKey) throws -> SecureSessionCrypting {
        guard let privateKey = currentPrivateKey else {
            throw SecureSessionManagerError.sessionNotStarted
        }

        let peerPublicKey = try P256.KeyAgreement.PublicKey(rawRepresentation: peerPubKey)

        let sharedSecret = try privateKey.sharedSecretFromKeyAgreement(with: peerPublicKey)

        let symmetricKey = sharedSecret.hkdfDerivedSymmetricKey(
            using: SHA256.self,
            salt: Data(),
            sharedInfo: Data(),
            outputByteCount: sharedSecretKeySize
        )

        return SecureSessionAesCryptor(key: symmetricKey)
    }
}
