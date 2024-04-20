import Foundation
import IrohaCrypto
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
    static let scryptN: UInt = 16384
    static let scryptP: UInt = 1
    static let scryptR: UInt = 8
    static let nonceLength = 24
    static let encryptionKeyLength: UInt = 32

    func encrypt(data: Data, password: String) throws -> Data {
        guard let salt = Data.random(of: Self.saltLength) else {
            throw CloudBackupCryptoManagerError.randomFunctionFailed
        }

        // TODO: Normalize the password?
        guard let passwordData = password.data(using: .utf8) else {
            throw CloudBackupCryptoManagerError.invalidPasswordFormat
        }

        let encryptionKey = try IRScryptKeyDeriviation().deriveKey(
            from: passwordData,
            salt: salt,
            scryptN: Self.scryptN,
            scryptP: Self.scryptP,
            scryptR: Self.scryptR,
            length: Self.encryptionKeyLength
        )

        guard let nonce = Data.random(of: Self.nonceLength) else {
            throw CloudBackupCryptoManagerError.randomFunctionFailed
        }

        let encrypted = try NaclSecretBox.secretBox(message: data, nonce: nonce, key: encryptionKey)
        return salt + nonce + encrypted
    }

    func decrypt(data: Data, password: String) throws -> Data {
        // TODO: Normalize the password?
        guard let passwordData = password.data(using: .utf8) else {
            throw CloudBackupCryptoManagerError.invalidPasswordFormat
        }

        let minimumDataLength = Self.saltLength + Self.nonceLength
        guard data.count >= minimumDataLength else {
            throw CloudBackupCryptoManagerError.invalidDecriptingData
        }

        let salt = Data(data[0 ..< Self.saltLength])
        let nonce = Data(data[Self.saltLength ..< minimumDataLength])
        let encryptedData = Data(data[minimumDataLength...])

        let encryptionKey = try IRScryptKeyDeriviation().deriveKey(
            from: passwordData,
            salt: salt,
            scryptN: Self.scryptN,
            scryptP: Self.scryptP,
            scryptR: Self.scryptR,
            length: Self.encryptionKeyLength
        )

        return try NaclSecretBox.open(box: encryptedData, nonce: nonce, key: encryptionKey)
    }
}
