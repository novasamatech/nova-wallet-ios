import Foundation

final class CloudBackupAvailabilityService: BaseSyncService {
    let fileManager: FileManager

    private(set) var state: Observable<CloudBackup.Availability> = .init(state: .notDetermined)

    let notificationCenter: NotificationCenter

    init(
        fileManager: FileManager,
        notificationCenter: NotificationCenter,
        logger: LoggerProtocol = Logger.shared
    ) {
        self.fileManager = fileManager
        self.notificationCenter = notificationCenter

        super.init(logger: logger)
    }

    private func getCloudId() -> CloudIdentifiable? {
        fileManager.ubiquityIdentityToken.map { ICloudIdentifier(cloudId: $0) }
    }

    override func performSyncUp() {
        let availability: CloudBackup.Availability = if let cloudId = getCloudId() {
            .available(CloudBackup.Available(cloudId: cloudId, hasStorage: true))
        } else {
            .unavailable
        }
    }

    override func stopSyncUp() {}
}
