import Foundation

protocol OperationDetailsDataProviderFactoryProtocol {
    func createProvider(for transaction: TransactionHistoryItem) -> OperationDetailsDataProviderProtocol?
}

final class OperationDetailsDataProviderFactory {
    let selectedAccount: MetaChainAccountResponse
    let chainAsset: ChainAsset
    let chainRegistry: ChainRegistryProtocol
    let accountRepositoryFactory: AccountRepositoryFactoryProtocol
    let operationQueue: OperationQueue

    init(
        selectedAccount: MetaChainAccountResponse,
        chainAsset: ChainAsset,
        chainRegistry: ChainRegistryProtocol,
        accountRepositoryFactory: AccountRepositoryFactoryProtocol,
        operationQueue: OperationQueue
    ) {
        self.selectedAccount = selectedAccount
        self.chainAsset = chainAsset
        self.chainRegistry = chainRegistry
        self.accountRepositoryFactory = accountRepositoryFactory
        self.operationQueue = operationQueue
    }
}

extension OperationDetailsDataProviderFactory: OperationDetailsDataProviderFactoryProtocol {
    // swiftlint:disable:next function_body_length
    func createProvider(for transaction: TransactionHistoryItem) -> OperationDetailsDataProviderProtocol? {
        guard
            let address = selectedAccount.chainAccount.toAddress(),
            let transactionType = transaction.type(for: address) else {
            return nil
        }

        switch transactionType {
        case .incoming, .outgoing:
            let walletRepository = accountRepositoryFactory.createMetaAccountRepository(
                for: nil,
                sortDescriptors: []
            )

            return OperationDetailsTransferProvider(
                selectedAccount: selectedAccount,
                chainAsset: chainAsset,
                transaction: transaction,
                walletRepository: walletRepository,
                operationQueue: operationQueue
            )
        case .reward, .slash:
            let walletRepository = accountRepositoryFactory.createMetaAccountRepository(
                for: nil,
                sortDescriptors: []
            )

            return OperationDetailsDirectStakingProvider(
                selectedAccount: selectedAccount,
                chainAsset: chainAsset,
                transaction: transaction,
                walletRepository: walletRepository,
                operationQueue: operationQueue
            )
        case .extrinsic:
            if chainAsset.asset.isEvmNative {
                return OperationDetailsContractProvider(
                    selectedAccount: selectedAccount,
                    chainAsset: chainAsset,
                    transaction: transaction
                )
            } else {
                return OperationDetailsExtrinsicProvider(
                    selectedAccount: selectedAccount,
                    chainAsset: chainAsset,
                    transaction: transaction
                )
            }
        case .poolReward, .poolSlash:
            guard
                let connection = chainRegistry.getConnection(for: chainAsset.chain.chainId),
                let runtimeService = chainRegistry.getRuntimeProvider(for: chainAsset.chain.chainId) else {
                return nil
            }

            return OperationDetailsPoolStakingProvider(
                selectedAccount: selectedAccount,
                chainAsset: chainAsset,
                transaction: transaction,
                poolsOperationFactory: NominationPoolsOperationFactory(operationQueue: operationQueue),
                connection: connection,
                runtimeService: runtimeService,
                operationQueue: operationQueue
            )
        }
    }
}
