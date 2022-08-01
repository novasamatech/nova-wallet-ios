import Foundation
import RobinHood

protocol WatchOnlyPresetRepositoryProtocol {
    func fetchPresetsWrapper() -> CompoundOperationWrapper<[WatchOnlyWallet]>
}

final class WatchOnlyPresetRepository {}

extension WatchOnlyPresetRepository: WatchOnlyPresetRepositoryProtocol {
    func fetchPresetsWrapper() -> CompoundOperationWrapper<[WatchOnlyWallet]> {
        let fetchOperation = ClosureOperation<[WatchOnlyWallet]> {
            guard let jsonUrl = R.file.watchOnlyPresetJson() else {
                return []
            }

            let data = try Data(contentsOf: jsonUrl)

            return try JSONDecoder().decode([WatchOnlyWallet].self, from: data)
        }

        return CompoundOperationWrapper(targetOperation: fetchOperation)
    }
}
