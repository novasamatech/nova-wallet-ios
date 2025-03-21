import Foundation
import Operation_iOS

protocol WatchOnlyPresetRepositoryProtocol {
    func fetchPresetsWrapper() -> CompoundOperationWrapper<[WatchOnlyWallet]>
}

final class WatchOnlyPresetRepository: JsonFileRepository<[WatchOnlyWallet]> {}

extension WatchOnlyPresetRepository: WatchOnlyPresetRepositoryProtocol {
    func fetchPresetsWrapper() -> CompoundOperationWrapper<[WatchOnlyWallet]> {
        fetchOperationWrapper(by: R.file.watchOnlyPresetJson(), defaultValue: [])
    }
}
