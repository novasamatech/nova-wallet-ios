import Foundation
import RobinHood

final class WalletManageInteractor: WalletsListInteractor {
    let repository: AnyDataProviderRepository<ManagedMetaAccountModel>
    let operationQueue: OperationQueue

    init(
        chainRegistry: ChainRegistryProtocol,
        walletListLocalSubscriptionFactory: WalletListLocalSubscriptionFactoryProtocol,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        repository: AnyDataProviderRepository<ManagedMetaAccountModel>,
        operationQueue: OperationQueue
    ) {
        self.repository = repository
        self.operationQueue = operationQueue

        super.init(
            chainRegistry: chainRegistry,
            walletListLocalSubscriptionFactory: walletListLocalSubscriptionFactory,
            walletLocalSubscriptionFactory: walletLocalSubscriptionFactory,
            priceLocalSubscriptionFactory: priceLocalSubscriptionFactory
        )
    }
}

extension WalletManageInteractor: WalletManageInteractorInputProtocol {
    func save(items: [ManagedMetaAccountModel]) {
        let operation = repository.saveOperation({ items }, { [] })
        operationQueue.addOperation(operation)
    }

    func remove(item: ManagedMetaAccountModel) {
        let operation = repository.saveOperation({ [] }, { [item.identifier] })
        operationQueue.addOperation(operation)
    }
}
