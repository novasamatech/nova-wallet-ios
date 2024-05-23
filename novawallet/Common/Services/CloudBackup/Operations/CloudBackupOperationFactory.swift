import Foundation
import RobinHood

enum CloudBackupOperationFactoryError: Error {
    case readingFailed(Error)
    case writingFailed(Error)
    case deletionFailed(Error)
    case conflictResolutionFailed(Error)
}

protocol CloudBackupOperationFactoryProtocol {
    func createReadingOperation(for url: URL) -> BaseOperation<Data?>
    func createWritingOperation(
        for url: URL,
        dataClosure: @escaping () throws -> Data
    ) -> BaseOperation<Void>
    func createDeletionOperation(for url: URL) -> BaseOperation<Void>
}

final class CloudBackupOperationFactory {
    let fileCoordinator: NSFileCoordinator
    let fileManager: FileManager
    let conflictsResolver: CloudBackupConflictsResolving

    init(fileCoordinator: NSFileCoordinator, fileManager: FileManager, conflictsResolver: CloudBackupConflictsResolving) {
        self.fileCoordinator = fileCoordinator
        self.fileManager = fileManager
        self.conflictsResolver = conflictsResolver
    }

    func read(
        using coordinator: NSFileCoordinator,
        fileManager: FileManager,
        conflictsResolver: CloudBackupConflictsResolving,
        url: URL
    ) -> BaseOperation<Data?> {
        ClosureOperation {
            if case let .failure(error) = conflictsResolver.resolveConflictsIfNeeded(
                using: coordinator,
                url: url
            ) {
                throw CloudBackupOperationFactoryError.conflictResolutionFailed(error)
            }

            var coordinatorError: NSError?
            var readError: Error?
            var optData: Data?

            coordinator.coordinate(
                readingItemAt: url,
                options: [],
                error: &coordinatorError
            ) { actualUrl in
                do {
                    var isDirectory: ObjCBool = false
                    if
                        fileManager.fileExists(atPath: actualUrl.path, isDirectory: &isDirectory),
                        !isDirectory.boolValue {
                        optData = try Data(contentsOf: actualUrl)
                    }
                } catch {
                    readError = error
                }
            }

            if let error = readError {
                throw CloudBackupOperationFactoryError.readingFailed(error)
            }

            if let error = coordinatorError {
                throw CloudBackupOperationFactoryError.readingFailed(error)
            }

            return optData
        }
    }

    func write(
        using coordinator: NSFileCoordinator,
        conflictsResolver: CloudBackupConflictsResolving,
        url: URL,
        dataClosure: @escaping () throws -> Data
    ) -> BaseOperation<Void> {
        ClosureOperation {
            if case let .failure(error) = conflictsResolver.resolveConflictsIfNeeded(
                using: coordinator,
                url: url
            ) {
                throw CloudBackupOperationFactoryError.conflictResolutionFailed(error)
            }

            var coordinatorError: NSError?
            var writeError: Error?

            let data = try dataClosure()

            coordinator.coordinate(
                writingItemAt: url,
                options: [.forMerging],
                error: &coordinatorError
            ) { actualUrl in
                do {
                    try data.write(to: actualUrl, options: .atomic)
                } catch {
                    writeError = error
                }
            }

            if let error = writeError {
                throw CloudBackupOperationFactoryError.writingFailed(error)
            }

            if let error = coordinatorError {
                throw CloudBackupOperationFactoryError.writingFailed(error)
            }
        }
    }

    func delete(
        using coordinator: NSFileCoordinator,
        fileManager: FileManager,
        conflictsResolver: CloudBackupConflictsResolving,
        url: URL
    ) -> BaseOperation<Void> {
        ClosureOperation {
            if case let .failure(error) = conflictsResolver.resolveConflictsIfNeeded(
                using: coordinator,
                url: url
            ) {
                throw CloudBackupOperationFactoryError.conflictResolutionFailed(error)
            }

            var coordinatorError: NSError?
            var deleteError: Error?

            coordinator.coordinate(
                writingItemAt: url,
                options: [.forDeleting],
                error: &coordinatorError
            ) { actualUrl in
                do {
                    try fileManager.removeItem(at: actualUrl)
                } catch {
                    deleteError = error
                }
            }

            if let error = deleteError {
                throw CloudBackupOperationFactoryError.deletionFailed(error)
            }

            if let error = coordinatorError {
                throw CloudBackupOperationFactoryError.deletionFailed(error)
            }
        }
    }
}

extension CloudBackupOperationFactory: CloudBackupOperationFactoryProtocol {
    func createReadingOperation(for url: URL) -> BaseOperation<Data?> {
        read(
            using: fileCoordinator,
            fileManager: fileManager,
            conflictsResolver: conflictsResolver,
            url: url
        )
    }

    func createWritingOperation(
        for url: URL,
        dataClosure: @escaping () throws -> Data
    ) -> BaseOperation<Void> {
        write(
            using: fileCoordinator,
            conflictsResolver: conflictsResolver,
            url: url,
            dataClosure: dataClosure
        )
    }

    func createDeletionOperation(for url: URL) -> BaseOperation<Void> {
        delete(
            using: fileCoordinator,
            fileManager: fileManager,
            conflictsResolver: conflictsResolver,
            url: url
        )
    }
}
