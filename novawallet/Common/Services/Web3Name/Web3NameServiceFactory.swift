import Foundation

protocol Web3NameServiceFactoryProtocol {
    func createService() -> Web3NameServiceProtocol?
}

final class Web3NameServiceFactory: Web3NameServiceFactoryProtocol {
    let chainRegistry: ChainRegistryProtocol
    let operationQueue: OperationQueue

    init(
        chainRegistry: ChainRegistryProtocol = ChainRegistryFacade.sharedRegistry,
        operationQueue: OperationQueue
    ) {
        self.chainRegistry = chainRegistry
        self.operationQueue = operationQueue
    }

    func createService() -> Web3NameServiceProtocol? {
        let kiltChainId = KnowChainId.kiltOnEnviroment
        let chainRegistry = ChainRegistryFacade.sharedRegistry

        guard let kiltConnection = chainRegistry.getConnection(for: kiltChainId),
              let kiltRuntimeService = chainRegistry.getRuntimeProvider(for: kiltChainId) else {
            return nil
        }

        let web3NamesOperationFactory = KiltWeb3NamesOperationFactory(operationQueue: operationQueue)

        let recipientRepositoryFactory = Web3TransferRecipientRepositoryFactory(
            integrityVerifierFactory: Web3TransferRecipientIntegrityVerifierFactory()
        )

        let slip44CoinsUrl = ApplicationConfig.shared.slip44URL
        let slip44CoinsProvider: AnySingleValueProvider<Slip44CoinList> = JsonDataProviderFactory.shared.getJson(
            for: slip44CoinsUrl
        )

        return Web3NameService(
            providerName: Web3NameProvider.kilt,
            slip44CoinsProvider: slip44CoinsProvider,
            web3NamesOperationFactory: web3NamesOperationFactory,
            runtimeService: kiltRuntimeService,
            connection: kiltConnection,
            transferRecipientRepositoryFactory: recipientRepositoryFactory,
            operationQueue: operationQueue
        )
    }
}
