import Foundation
import CryptoKit

enum SecureSessionAesCryptorError: Error {
    case cipherGenerationFailed
}

final class SecureSessionAesCryptor {
    let key: SymmetricKey
    let nonceSize: Int

    init(key: SymmetricKey, nonceSize: Int = 12) {
        self.key = key
        self.nonceSize = nonceSize
    }
}

extension SecureSessionAesCryptor: SecureSessionCrypting {
    func encrypt(_ message: SecureSession.Message) throws -> SecureSession.Cipher {
        let nonce = try AES.GCM.Nonce(data: Data((0 ..< nonceSize).map { _ in UInt8.random(in: 0 ... 255) }))
        let sealedBox = try AES.GCM.seal(message, using: key, nonce: nonce)

        guard let combinedData = sealedBox.combined else {
            throw SecureSessionAesCryptorError.cipherGenerationFailed
        }

        return combinedData
    }

    func decrypt(_ cipher: SecureSession.Cipher) throws -> SecureSession.Message {
        let receivedSealedBox = try AES.GCM.SealedBox(combined: cipher)

        return try AES.GCM.open(receivedSealedBox, using: key)
    }
}
