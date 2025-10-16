import Foundation
@testable import novawallet

final class MockCloudBackupAvailabilityService {
    private(set) var stateObserver: Observable<CloudBackup.Availability>

    init(
        availability: CloudBackup.Availability = .available(
            .init(
                cloudId: ICloudIdentifier(cloudId: UUID().uuidString as NSString))
        )
    ) {
        stateObserver = .init(state: availability)
    }
}

extension MockCloudBackupAvailabilityService: CloudBackupAvailabilityServiceProtocol {
    func setup() {}
    func throttle() {}
}
