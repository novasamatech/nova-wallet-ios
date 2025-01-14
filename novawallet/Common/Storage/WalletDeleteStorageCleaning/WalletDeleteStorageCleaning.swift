import Foundation
import Operation_iOS

protocol WalletDeleteStorageCleaning {
    func cleanStorage(for deletedWallet: MetaAccountModel) -> CompoundOperationWrapper<Void>
}

final class WalletDeleteStorageCleaner {
    private let cleanersCascade: [WalletDeleteStorageCleaning]

    init(cleanersCascade: [WalletDeleteStorageCleaning]) {
        self.cleanersCascade = cleanersCascade
    }
}

// MARK: WalletDeleteStorageCleaning

extension WalletDeleteStorageCleaner: WalletDeleteStorageCleaning {
    func cleanStorage(for deletedWallet: MetaAccountModel) -> CompoundOperationWrapper<Void> {
        let wrappers = cleanersCascade.map { $0.cleanStorage(for: deletedWallet) }

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
