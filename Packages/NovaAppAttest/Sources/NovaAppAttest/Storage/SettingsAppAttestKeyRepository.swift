import Foundation
import Operation_iOS
import Keystore_iOS

enum SettingsAppAttestKeyRepositoryError: Error {
    case sliceFetchUnsupported
}

/// Persists app attest key rows as one JSON map under a single settings key.
public final class SettingsAppAttestKeyRepository {
    // Stable on-disk settings key: changing this string orphans every stored row.
    static let storageKey = "appAttestKeys"

    private let settingsManager: SettingsManagerProtocol
    private let mutex = NSLock()

    public init(settingsManager: SettingsManagerProtocol) {
        self.settingsManager = settingsManager
    }
}

// MARK: - Private

private extension SettingsAppAttestKeyRepository {
    func loadMap() -> [String: AppAttestKeySettings] {
        settingsManager.value(of: [String: AppAttestKeySettings].self, for: Self.storageKey) ?? [:]
    }

    func storeMap(_ map: [String: AppAttestKeySettings]) {
        if map.isEmpty {
            settingsManager.removeValue(for: Self.storageKey)
        } else {
            settingsManager.set(value: map, for: Self.storageKey)
        }
    }

    func withMap<T>(_ body: (inout [String: AppAttestKeySettings]) -> T) -> T {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        var map = loadMap()
        let result = body(&map)
        storeMap(map)

        return result
    }

    func readMap() -> [String: AppAttestKeySettings] {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        return loadMap()
    }
}

// MARK: - DataProviderRepositoryProtocol

extension SettingsAppAttestKeyRepository: DataProviderRepositoryProtocol {
    public typealias Model = AppAttestKeySettings

    public func fetchOperation(
        by modelIdClosure: @escaping () throws -> String,
        options _: RepositoryFetchOptions
    ) -> BaseOperation<AppAttestKeySettings?> {
        ClosureOperation { [weak self] in
            let identifier = try modelIdClosure()

            return self?.readMap()[identifier]
        }
    }

    public func fetchAllOperation(with _: RepositoryFetchOptions) -> BaseOperation<[AppAttestKeySettings]> {
        ClosureOperation { [weak self] in
            self?.readMap().values.sorted { $0.identifier < $1.identifier } ?? []
        }
    }

    public func fetchOperation(
        by _: RepositorySliceRequest,
        options _: RepositoryFetchOptions
    ) -> BaseOperation<[AppAttestKeySettings]> {
        BaseOperation.createWithError(SettingsAppAttestKeyRepositoryError.sliceFetchUnsupported)
    }

    public func saveOperation(
        _ updateModelsBlock: @escaping () throws -> [AppAttestKeySettings],
        _ deleteIdsBlock: @escaping () throws -> [String]
    ) -> BaseOperation<Void> {
        ClosureOperation { [weak self] in
            let updated = try updateModelsBlock()
            let deletedIds = try deleteIdsBlock()

            self?.withMap { map in
                for row in updated {
                    map[row.identifier] = row
                }

                for identifier in deletedIds {
                    map[identifier] = nil
                }
            }
        }
    }

    public func replaceOperation(
        _ newModelsBlock: @escaping () throws -> [AppAttestKeySettings]
    ) -> BaseOperation<Void> {
        ClosureOperation { [weak self] in
            let rows = try newModelsBlock()

            self?.withMap { map in
                map = rows.reduce(into: [:]) { accumulator, row in
                    accumulator[row.identifier] = row
                }
            }
        }
    }

    public func fetchCountOperation() -> BaseOperation<Int> {
        ClosureOperation { [weak self] in
            self?.readMap().count ?? 0
        }
    }

    public func deleteAllOperation() -> BaseOperation<Void> {
        ClosureOperation { [weak self] in
            self?.withMap { map in
                map = [:]
            }
        }
    }
}
