import Foundation
import Operation_iOS

protocol WalletStorageCleaning {
    func cleanStorage(
        for removedItems: @escaping () throws -> [MetaAccountModel]
    ) -> CompoundOperationWrapper<Void>
}
