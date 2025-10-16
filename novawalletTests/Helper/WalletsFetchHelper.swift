import Foundation
@testable import novawallet
import Operation_iOS

enum WalletsFetchHelper {
    static func fetchWallets(
        using repositoryFactory: AccountRepositoryFactoryProtocol
    ) throws -> Set<ManagedMetaAccountModel> {
        let queue = OperationQueue()

        let operation = repositoryFactory.createManagedMetaAccountRepository(
            for: nil,
            sortDescriptors: []
        ).fetchAllOperation(with: RepositoryFetchOptions())

        queue.addOperations([operation], waitUntilFinished: true)

        let wallets = try operation.extractNoCancellableResultData()

        return Set(wallets)
    }
}
