import Foundation
@testable import novawallet

final class MockCloudBackupFileManager {
    let baseUrl: URL
    let name: String

    init(
        baseUrl: URL = URL(string: "file://home/dummy")!,
        name: String = CloudBackup.walletsFilename
    ) {
        self.baseUrl = baseUrl
        self.name = name
    }
}

extension MockCloudBackupFileManager: CloudBackupFileManaging {
    func getFileName() -> String {
        name
    }

    func getFileUrl() -> URL? {
        (getBaseUrl() as? NSURL)?.appendingPathComponent(getFileName())
    }

    func getBaseUrl() -> URL? {
        baseUrl
    }
}
