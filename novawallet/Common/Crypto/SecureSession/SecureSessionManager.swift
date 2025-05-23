import Foundation
import NovaCrypto
import CryptoKit

enum SecureSessionManagerError: Error {
    case sessionNotStarted
}

final class SecureSessionManager {
    private var currentPrivateKey: P256.KeyAgreement.PrivateKey?
    let sharedSecretKeySize: Int
    let auth: Data
    let salt: Data

    init(
        auth: Data,
        salt: Data,
        sharedSecretKeySize: Int = 32
    ) {
        self.auth = auth
        self.salt = salt
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
            salt: salt,
            sharedInfo: auth,
            outputByteCount: sharedSecretKeySize
        )

        return SecureSessionAesCryptor(key: symmetricKey)
    }
}
