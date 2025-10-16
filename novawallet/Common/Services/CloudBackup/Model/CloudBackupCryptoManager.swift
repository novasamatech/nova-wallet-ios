import Foundation
import Scrypt
import TweetNacl

protocol CloudBackupCryptoManagerProtocol {
    func encrypt(data: Data, password: String) throws -> Data
    func decrypt(data: Data, password: String) throws -> Data
}

enum CloudBackupCryptoManagerError: Error {
    case invalidPasswordFormat
    case randomFunctionFailed
    case invalidDecriptingData
}

final class CloudBackupScryptSalsaCryptoManager: CloudBackupCryptoManagerProtocol {
    static let saltLength: Int = 32
    static let scryptN: UInt64 = 16384
    static let scryptP: UInt32 = 1
    static let scryptR: UInt32 = 8
    static let nonceLength = 24
    static let encryptionKeyLength: Int = 32

    private func deriveEncryptionKey(password: Data, salt: Data) throws -> Data {
        let encryptionKeyBytes = try Scrypt.scrypt(
            password: password.bytes,
            salt: salt.bytes,
            length: Self.encryptionKeyLength,
            N: Self.scryptN,
            r: Self.scryptR,
            p: Self.scryptP
        )

        return Data(encryptionKeyBytes)
    }

    func normalize(password: String) -> Data? {
        password.decomposedStringWithCompatibilityMapping.data(using: .utf8)
    }

    func encrypt(data: Data, password: String) throws -> Data {
        guard let salt = Data.random(of: Self.saltLength) else {
            throw CloudBackupCryptoManagerError.randomFunctionFailed
        }

        guard let passwordData = normalize(password: password) else {
            throw CloudBackupCryptoManagerError.invalidPasswordFormat
        }

        let encryptionKey = try deriveEncryptionKey(password: passwordData, salt: salt)

        guard let nonce = Data.random(of: Self.nonceLength) else {
            throw CloudBackupCryptoManagerError.randomFunctionFailed
        }

        let encrypted = try NaclSecretBox.secretBox(message: data, nonce: nonce, key: encryptionKey)
        return salt + nonce + encrypted
    }

    func decrypt(data: Data, password: String) throws -> Data {
        guard let passwordData = normalize(password: password) else {
            throw CloudBackupCryptoManagerError.invalidPasswordFormat
        }

        let minimumDataLength = Self.saltLength + Self.nonceLength
        guard data.count >= minimumDataLength else {
            throw CloudBackupCryptoManagerError.invalidDecriptingData
        }

        let salt = Data(data[0 ..< Self.saltLength])
        let nonce = Data(data[Self.saltLength ..< minimumDataLength])
        let encryptedData = Data(data[minimumDataLength...])

        let encryptionKey = try deriveEncryptionKey(password: passwordData, salt: salt)

        return try NaclSecretBox.open(box: encryptedData, nonce: nonce, key: encryptionKey)
    }
}
