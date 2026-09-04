import Foundation
import Operation_iOS
import Keystore_iOS

enum SettingsAppAttestKeyRepositoryError: Error {
    case sliceFetchUnsupported
}

/// Persists the app attest key rows as one JSON-encoded `[String: AppAttestKeySettings]`
/// map under a single settings key.
///
/// One map rather than a key per row because `SettingsManagerProtocol` offers no key
/// enumeration: `deleteAllOperation()` must clear every client's row, and with per-row keys
/// there would be no way to find them. As one map it is a single `removeValue`.
///
/// The lock is not optional. `BackendAttestationProvider` signs on a shared *concurrent*
/// queue and UserDefaults gives per-key atomicity only, so an unguarded read-modify-write
/// of the map drops concurrent saves.
final class SettingsAppAttestKeyRepository {
    /// A bare string literal rather than a `SettingsKey` case — every other settings key in
    /// the app goes through that enum. This file moves into the standalone `NovaAppAttest`
    /// package next, which cannot depend on the app's `SettingsKey` enum, so the key has to
    /// be self-contained here rather than delegate to it.
    static let storageKey = "appAttestKeys"

    private let settingsManager: SettingsManagerProtocol
    private let mutex = NSLock()

    init(settingsManager: SettingsManagerProtocol) {
        self.settingsManager = settingsManager
    }
}

// MARK: - Private

private extension SettingsAppAttestKeyRepository {
    /// Callers must hold `mutex`. Decodes the whole map as one JSON blob via `try?`
    /// (`SettingsManagerProtocol.value(of:for:)`), so adding a non-optional field to
    /// `AppAttestKeySettings` later would silently discard *every* row rather than the one
    /// row that fails to decode. The consequence is benign here — a fresh key and a
    /// re-register — and it is actually an improvement on the CoreData mapper this
    /// replaced, which threw `CommonError.dataCorruption` into a fetch that `resolveRow`
    /// (`BackendAttestationProvider.swift:88-102`) does not absorb, wedging attestation
    /// permanently.
    func loadMap() -> [String: AppAttestKeySettings] {
        settingsManager.value(of: [String: AppAttestKeySettings].self, for: Self.storageKey) ?? [:]
    }

    /// Callers must hold `mutex`. An empty map removes the key outright rather than storing
    /// `{}`, so an opt-out leaves nothing behind in the settings dump.
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
    typealias Model = AppAttestKeySettings

    func fetchOperation(
        by modelIdClosure: @escaping () throws -> String,
        options _: RepositoryFetchOptions
    ) -> BaseOperation<AppAttestKeySettings?> {
        ClosureOperation { [weak self] in
            let identifier = try modelIdClosure()

            return self?.readMap()[identifier]
        }
    }

    func fetchAllOperation(with _: RepositoryFetchOptions) -> BaseOperation<[AppAttestKeySettings]> {
        ClosureOperation { [weak self] in
            // Stable order so the result is deterministic. The provider never depends on
            // it; the tests do.
            self?.readMap().values.sorted { $0.identifier < $1.identifier } ?? []
        }
    }

    /// `RepositorySliceRequest` keeps its offset, count and reversed flag internal to
    /// Operation-iOS, so a slice cannot be honoured from outside that module at all.
    /// Nothing asks for one — the provider fetches by identifier — and
    /// `InMemoryDataProviderRepository` refuses slices the same way.
    func fetchOperation(
        by _: RepositorySliceRequest,
        options _: RepositoryFetchOptions
    ) -> BaseOperation<[AppAttestKeySettings]> {
        BaseOperation.createWithError(SettingsAppAttestKeyRepositoryError.sliceFetchUnsupported)
    }

    func saveOperation(
        _ updateModelsBlock: @escaping () throws -> [AppAttestKeySettings],
        _ deleteIdsBlock: @escaping () throws -> [String]
    ) -> BaseOperation<Void> {
        ClosureOperation { [weak self] in
            // Evaluated before the lock is taken: these closures carry the provider's epoch
            // guards and may throw, and a throw must not leave the map half-written.
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

    func replaceOperation(
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

    func fetchCountOperation() -> BaseOperation<Int> {
        ClosureOperation { [weak self] in
            self?.readMap().count ?? 0
        }
    }

    /// A bare requirement of `DataProviderRepositoryProtocol`, not one the protocol
    /// extension defaults, so it is implemented here. Emptying the whole map is the point:
    /// the opt-out wipe has to take rows left behind by earlier client ids too.
    func deleteAllOperation() -> BaseOperation<Void> {
        ClosureOperation { [weak self] in
            self?.withMap { map in
                map = [:]
            }
        }
    }
}
