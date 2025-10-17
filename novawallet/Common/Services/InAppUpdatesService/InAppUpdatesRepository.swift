import Foundation
import Operation_iOS

protocol InAppUpdatesReleasesRepositoryProtocol {
    func fetchReleasesWrapper() -> CompoundOperationWrapper<[Release]>
}

protocol InAppUpdatesChangeLogsRepositoryProtocol {
    func fetchChangeLogOperation(for version: ReleaseVersion) -> BaseOperation<String>
}

final class InAppUpdatesRepository: JsonFileRepository<[Release]> {
    let urlProvider: InAppUpdatesUrlProviderProtocol

    init(urlProvider: InAppUpdatesUrlProviderProtocol) {
        self.urlProvider = urlProvider
    }
}

extension InAppUpdatesRepository: InAppUpdatesReleasesRepositoryProtocol {
    func fetchReleasesWrapper() -> CompoundOperationWrapper<[Release]> {
        let url = urlProvider.releaseURL
        return fetchOperationWrapper(by: url, defaultValue: [])
    }
}

extension InAppUpdatesRepository: InAppUpdatesChangeLogsRepositoryProtocol {
    func fetchChangeLogOperation(for version: ReleaseVersion) -> BaseOperation<String> {
        let url = urlProvider.versionURL(version)

        let fetchOperation = ClosureOperation<String> {
            let data = try Data(contentsOf: url)
            guard let content = String(data: data, encoding: .utf8) else {
                throw InAppUpdatesRepositoryError.emptyChangelog
            }
            return content
        }

        return fetchOperation
    }
}

enum InAppUpdatesRepositoryError: Error {
    case emptyChangelog
}
