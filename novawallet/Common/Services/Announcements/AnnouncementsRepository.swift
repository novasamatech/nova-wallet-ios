import Foundation
import Operation_iOS

protocol AnnouncementsRepositoryProtocol {
    func fetchAnnouncementsWrapper(for section: AnnouncementSection) -> CompoundOperationWrapper<[Announcement]>
}

final class AnnouncementsRepository {
    @Atomic(defaultValue: nil)
    private var cachedRemote: AnnouncementsRemote?

    private let fetchOperationFactory: AnnouncementsFetchOperationFactoryProtocol
    private let logger: LoggerProtocol

    init(
        fetchOperationFactory: AnnouncementsFetchOperationFactoryProtocol = AnnouncementsFetchOperationFactory(),
        logger: LoggerProtocol = Logger.shared
    ) {
        self.fetchOperationFactory = fetchOperationFactory
        self.logger = logger
    }
}

// MARK: - AnnouncementsRepositoryProtocol

extension AnnouncementsRepository: AnnouncementsRepositoryProtocol {
    func fetchAnnouncementsWrapper(for section: AnnouncementSection) -> CompoundOperationWrapper<[Announcement]> {
        if let cachedRemote {
            return .createWithResult(cachedRemote.announcements(for: section))
        }

        let fetchOperation = fetchOperationFactory.fetchOperation()

        let mapOperation = ClosureOperation<[Announcement]> { [weak self] in
            do {
                let remote = try fetchOperation.extractNoCancellableResultData()
                self?.cachedRemote = remote
                return remote.announcements(for: section)
            } catch {
                self?.logger.warning("Failed to fetch announcements: \(error)")
                return []
            }
        }

        mapOperation.addDependency(fetchOperation)

        return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: [fetchOperation])
    }
}

// MARK: - Shared

extension AnnouncementsRepository {
    static let shared = AnnouncementsRepository()
}
