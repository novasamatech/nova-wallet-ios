import Foundation
import Operation_iOS

struct WalletStorageCleaningDependencies {
    let changedItemsClosure: () throws -> [MetaAccountModel]
    let allWalletsClosure: (() throws -> [MetaAccountModel.Id: MetaAccountModel])?
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
        using dependencies: WalletStorageCleaningDependencies
    ) -> CompoundOperationWrapper<Void> {
        let wrappers = cleanersCascade.map { $0.cleanStorage(using: dependencies) }

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
