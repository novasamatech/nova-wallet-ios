import RobinHood

protocol InAppUpdatesRepositoryProtocol {
    func fetchReleasesWrapper() -> CompoundOperationWrapper<[Release]>
}

final class InAppUpdatesRepository: JsonFileRepository<[Release]> {}

extension InAppUpdatesRepository: InAppUpdatesRepositoryProtocol {
    func fetchReleasesWrapper() -> CompoundOperationWrapper<[Release]> {
        let url = ApplicationConfig.shared.inAppUpdatesEntrypointURL
        return fetchOperationWrapper(by: url, defaultValue: [])
    }
}
