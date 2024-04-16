import Foundation

protocol CloudBackupValidating {
    func validate(
        publicData: CloudBackup.PublicData,
        matches privateData: CloudBackup.DecryptedFileModel.PrivateData
    ) -> Bool
}
