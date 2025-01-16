import Foundation
import Operation_iOS

final class RemovedWalletStorageCleaner {
    private let cleanersCascade: [WalletStorageCleaning]

    init(cleanersCascade: [WalletStorageCleaning]) {
        self.cleanersCascade = cleanersCascade
    }
}

// MARK: WalletStorageCleaning

extension RemovedWalletStorageCleaner: WalletStorageCleaning {
    func cleanStorage(
        for removedItems: @escaping () throws -> [MetaAccountModel]
    ) -> CompoundOperationWrapper<Void> {
        let wrappers = cleanersCascade.map { $0.cleanStorage(for: removedItems) }

        let mergeOperation = ClosureOperation {
            _ = try wrappers.map { try $0.targetOperation.extractNoCancellableResultData() }

            return
        }

        wrappers.forEach { mergeOperation.addDependency($0.targetOperation) }

        let dependencies = wrappers.flatMap(\.allOperations)

        return CompoundOperationWrapper(
            targetOperation: mergeOperation,
            dependencies: dependencies
        )
    }
}
