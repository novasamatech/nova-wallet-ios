import Foundation
import Operation_iOS

struct WalletStorageCleaningProviders {
    let changesProvider: () -> [DataProviderChange<ManagedMetaAccountModel>]
    let walletsBeforeChangesProvider: () -> [MetaAccountModel.Id: ManagedMetaAccountModel]
}

final class WalletStorageCleaner {
    private let cleanersCascade: [WalletStorageCleaning]

    init(cleanersCascade: [WalletStorageCleaning]) {
        self.cleanersCascade = cleanersCascade
    }
}

// MARK: WalletStorageCleaning

extension WalletStorageCleaner: WalletStorageCleaning {
    func cleanStorage(
        using providers: WalletStorageCleaningProviders
    ) -> CompoundOperationWrapper<Void> {
        let wrappers = cleanersCascade.map { $0.cleanStorage(using: providers) }

        let mergeOperation = ClosureOperation {
            _ = try wrappers.map { try $0.targetOperation.extractNoCancellableResultData() }

            return
        }

        wrappers.forEach { mergeOperation.addDependency($0.targetOperation) }

        let wrapperDependencies = wrappers.flatMap(\.allOperations)

        return CompoundOperationWrapper(
            targetOperation: mergeOperation,
            dependencies: wrapperDependencies
        )
    }
}
