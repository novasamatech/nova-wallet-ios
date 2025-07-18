import Foundation
import Operation_iOS

protocol WalletDelayedExecutionRepositoryProtocol {
    func createVerifier() -> CompoundOperationWrapper<WalletDelayedExecVerifing>
}

final class WalletDelayedExecutionRepository {
    let walletRepository: AnyDataProviderRepository<MetaAccountModel>

    init(walletRepository: AnyDataProviderRepository<MetaAccountModel>) {
        self.walletRepository = walletRepository
    }

    init(userStorageFacade: StorageFacadeProtocol) {
        walletRepository = AccountRepositoryFactory(storageFacade: userStorageFacade).createMetaAccountRepository(
            for: nil,
            sortDescriptors: []
        )
    }
}

extension WalletDelayedExecutionRepository: WalletDelayedExecutionRepositoryProtocol {
    func createVerifier() -> CompoundOperationWrapper<WalletDelayedExecVerifing> {
        let allWalletsOperation = walletRepository.fetchAllOperation(with: RepositoryFetchOptions())

        let mapOperation = ClosureOperation<WalletDelayedExecVerifing> {
            let allWallets = try allWalletsOperation.extractNoCancellableResultData().reduceToDict()

            return WalletDelayedExecVerifier(allWallets: allWallets)
        }

        mapOperation.addDependency(allWalletsOperation)

        return CompoundOperationWrapper(
            targetOperation: mapOperation,
            dependencies: [allWalletsOperation]
        )
    }
}
