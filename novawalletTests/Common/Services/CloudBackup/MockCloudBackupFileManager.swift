import Foundation
@testable import novawallet

final class MockCloudBackupFileManager {
    let baseUrl: URL
    let name: String
    let tempName: String
    
    init(
        baseUrl: URL = URL(string: "file://home/dummy")!,
        name: String = CloudBackup.walletsFilename,
        tempName: String = CloudBackup.walletsTempFilename
    ) {
        self.baseUrl = baseUrl
        self.name = name
        self.tempName = tempName
    }
}

extension MockCloudBackupFileManager: CloudBackupFileManaging {
    func getFileName() -> String {
        return name
    }
    
    func getFileUrl() -> URL? {
        (getBaseUrl() as? NSURL)?.appendingPathComponent(getFileName())
    }
    
    func getBaseUrl() -> URL? {
        baseUrl
    }
    
    func getTempUrl() -> URL? {
        (getBaseUrl() as? NSURL)?.appendingPathComponent(tempName)
    }
}
