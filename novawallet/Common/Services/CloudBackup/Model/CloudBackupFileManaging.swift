import Foundation

protocol CloudBackupFileManaging {
    func getFileName() -> String
    func getFileUrl() -> URL?
    func getTempUrl() -> URL?
    func getBaseUrl() -> URL?
}

final class ICloudBackupFileManager {
    let fileManager: FileManager

    init(fileManager: FileManager) {
        self.fileManager = fileManager
    }
}

extension ICloudBackupFileManager: CloudBackupFileManaging {
    func getFileName() -> String {
        CloudBackup.walletsFilename
    }

    func getBaseUrl() -> URL? {
        fileManager.url(
            forUbiquityContainerIdentifier: CloudBackup.containerId
        )?.appendingPathComponent("Documents", conformingTo: .directory)
    }

    func getFileUrl() -> URL? {
        let baseUrl = getBaseUrl() as? NSURL
        return baseUrl?.appendingPathComponent(getFileName())
    }

    func getTempUrl() -> URL? {
        let baseUrl = getBaseUrl() as? NSURL
        return baseUrl?.appendingPathComponent(CloudBackup.walletsTempFilename)
    }
}
