import Foundation

protocol CloudBackupValidating {
    func validate(
        publicData: CloudBackup.PublicData,
        matches privateData: CloudBackup.DecryptedFileModel.PrivateData
    ) -> Bool
}

final class ICloudBackupValidator {}

extension ICloudBackupValidator: CloudBackupValidating {
    func validate(
        publicData _: CloudBackup.PublicData,
        matches _: CloudBackup.DecryptedFileModel.PrivateData
    ) -> Bool {
        // TODO: Implement validation
        true
    }
}
