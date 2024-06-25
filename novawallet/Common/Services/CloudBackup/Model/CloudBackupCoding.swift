import Foundation

protocol CloudBackupCoding {
    func encode(backup: CloudBackup.EncryptedFileModel) throws -> Data
    func decode(data: Data) throws -> CloudBackup.EncryptedFileModel
}

final class CloudBackupCoder {}

extension CloudBackupCoder: CloudBackupCoding {
    func encode(backup: CloudBackup.EncryptedFileModel) throws -> Data {
        try JSONEncoder().encode(backup)
    }

    func decode(data: Data) throws -> CloudBackup.EncryptedFileModel {
        try JSONDecoder().decode(CloudBackup.EncryptedFileModel.self, from: data)
    }
}
