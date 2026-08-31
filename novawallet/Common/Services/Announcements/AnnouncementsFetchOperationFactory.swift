import Foundation
import Operation_iOS

protocol AnnouncementsFetchOperationFactoryProtocol {
    func fetchOperation() -> BaseOperation<AnnouncementsRemote>
}

final class AnnouncementsFetchOperationFactory: BaseFetchOperationFactory {
    private let announcementsPath: String

    init(announcementsPath: String = ApplicationConfig.shared.announcementsPath) {
        self.announcementsPath = announcementsPath
    }
}

// MARK: - Private

private extension AnnouncementsFetchOperationFactory {
    func createURL() -> URL? {
        URL(string: announcementsPath)?.appendingPathComponent(Constants.configPath)
    }
}

// MARK: - AnnouncementsFetchOperationFactoryProtocol

extension AnnouncementsFetchOperationFactory: AnnouncementsFetchOperationFactoryProtocol {
    func fetchOperation() -> BaseOperation<AnnouncementsRemote> {
        guard let url = createURL() else { return .createWithError(NetworkBaseError.invalidUrl) }

        return createFetchOperation(
            from: url,
            shouldUseCache: false,
            timeout: Constants.timeout
        )
    }
}

// MARK: - Constants

private extension AnnouncementsFetchOperationFactory {
    enum Constants {
        static let timeout: TimeInterval = 10

        static var configPath: String {
            #if F_RELEASE
                "announcements.json"
            #else
                "announcements_dev.json"
            #endif
        }
    }
}
