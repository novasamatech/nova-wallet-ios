import Foundation

protocol CloudBackupConflictsResolving {
    func resolveConflictsIfNeeded(using coordinator: NSFileCoordinator, url: URL) -> Result<Void, Error>
}

final class CloudBackupConflictsResolver {}

extension CloudBackupConflictsResolver: CloudBackupConflictsResolving {
    func resolveConflictsIfNeeded(using coordinator: NSFileCoordinator, url: URL) -> Result<Void, Error> {
        guard let versions = NSFileVersion.otherVersionsOfItem(at: url), !versions.isEmpty else {
            return .success(())
        }

        var coordinatorError: NSError?
        var deleteError: Error?

        coordinator.coordinate(
            writingItemAt: url,
            options: [.forDeleting],
            error: &coordinatorError
        ) { actualUrl in
            do {
                try NSFileVersion.removeOtherVersionsOfItem(at: actualUrl)
            } catch {
                deleteError = error
            }
        }

        if let deleteError {
            return .failure(deleteError)
        }

        if let coordinatorError {
            return .failure(coordinatorError)
        }

        return .success(())
    }
}
