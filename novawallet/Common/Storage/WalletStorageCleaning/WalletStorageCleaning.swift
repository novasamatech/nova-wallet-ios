import Foundation
import Operation_iOS

protocol WalletStorageCleaning {
    func cleanStorage(
        using dependencies: WalletStorageCleaningDependencies
    ) -> CompoundOperationWrapper<Void>
}
