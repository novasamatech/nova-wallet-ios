import Foundation

protocol CloudBackupServiceFactoryProtocol {
    var baseUrl: URL? { get }

    func createAvailabilityService() -> CloudBackupAvailabilityServiceProtocol
    func createStorageManager(for baseUrl: URL) -> CloudBackupStorageManaging
    func createOperationFactory() -> CloudBackupOperationFactoryProtocol
}
