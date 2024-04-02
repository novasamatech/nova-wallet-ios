import Foundation

protocol CloudBackupAvailabilityServiceProtocol: ApplicationServiceProtocol {
    var stateObserver: Observable<CloudBackup.Availability> { get }
}

final class CloudBackupAvailabilityService {
    let fileManager: FileManager
    let logger: LoggerProtocol

    private(set) var stateObserver: Observable<CloudBackup.Availability> = .init(state: .notDetermined)

    init(fileManager: FileManager, logger: LoggerProtocol = Logger.shared) {
        self.fileManager = fileManager
        self.logger = logger
    }

    private func getCloudId() -> CloudIdentifiable? {
        fileManager.ubiquityIdentityToken.map { ICloudIdentifier(cloudId: $0) }
    }

    private func updateState() {
        let availability: CloudBackup.Availability = if let cloudId = getCloudId() {
            .available(CloudBackup.Available(cloudId: cloudId))
        } else {
            .unavailable
        }

        stateObserver.state = availability
    }
}

extension CloudBackupAvailabilityService: CloudBackupAvailabilityServiceProtocol {
    func setup() {
        updateState()
    }

    func throttle() {}
}
