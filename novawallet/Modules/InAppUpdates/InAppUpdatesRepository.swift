import RobinHood

protocol InAppUpdatesRepositoryProtocol {
    func fetchReleasesWrapper() -> CompoundOperationWrapper<[Release]>
    func fetchChangeLogOperation(for version: Version) -> BaseOperation<String>
}

final class InAppUpdatesRepository: JsonFileRepository<[Release]> {}

extension InAppUpdatesRepository: InAppUpdatesRepositoryProtocol {
    func fetchReleasesWrapper() -> CompoundOperationWrapper<[Release]> {
        let url = ApplicationConfig.shared.inAppUpdatesEntrypointURL
        return fetchOperationWrapper(by: url, defaultValue: [])
    }

    func fetchChangeLogOperation(for version: Version) -> BaseOperation<String> {
        let changelogURL = ApplicationConfig.shared.inAppUpdatesChangelogsURL
        let fileName = [
            version.major,
            version.minor,
            version.patch
        ]
        .map { String($0) }
        .joined(separator: "_")
        .appending(".md")

        let url = changelogURL.appendingPathComponent(fileName)

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
