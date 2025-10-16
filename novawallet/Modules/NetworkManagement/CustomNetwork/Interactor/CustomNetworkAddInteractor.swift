import Foundation
import SubstrateSdk
import Operation_iOS

final class CustomNetworkAddInteractor: CustomNetworkBaseInteractor {
    private var networkToAdd: ChainModel?

    init(
        networkToAdd: ChainModel?,
        chainRegistry: ChainRegistryProtocol,
        customNetworkSetupFactory: CustomNetworkSetupFactoryProtocol,
        connectionFactory: ConnectionFactoryProtocol,
        repository: AnyDataProviderRepository<ChainModel>,
        priceIdParser: PriceUrlParserProtocol,
        setupFinishStrategyFactory: CustomNetworkSetupFinishStrategyFactory,
        operationQueue: OperationQueue
    ) {
        self.networkToAdd = networkToAdd

        super.init(
            chainRegistry: chainRegistry,
            customNetworkSetupFactory: customNetworkSetupFactory,
            connectionFactory: connectionFactory,
            repository: repository,
            priceIdParser: priceIdParser,
            setupFinishStrategyFactory: setupFinishStrategyFactory,
            operationQueue: operationQueue
        )
    }

    override func completeSetup() {
        guard let networkToAdd, let node = networkToAdd.nodes.first else {
            return
        }

        presenter?.didReceive(
            knownChain: networkToAdd,
            selectedNode: node
        )
    }
}

// MARK: CustomNetworkAddInteractorInputProtocol

extension CustomNetworkAddInteractor: CustomNetworkAddInteractorInputProtocol {
    func addNetwork(with request: CustomNetwork.AddRequest) {
        setupFinishStrategy = setupFinishStrategyFactory.createAddNewStrategy(preConfiguredNetwork: networkToAdd)

        let type: CustomNetworkType = if let networkToAdd {
            networkToAdd.isPureEvm ? .evm : .substrate
        } else {
            request.networkType
        }

        let setupRequest = CustomNetwork.SetupRequest(
            from: request,
            networkType: type,
            iconUrl: networkToAdd?.icon,
            networkSetupType: .full
        )

        setupChain(with: setupRequest)
    }

    func fetchNetworkProperties(for url: String) {
        setupFinishStrategy = setupFinishStrategyFactory.createProvideStrategy()

        let request = CustomNetwork.SetupRequest(
            networkType: .substrate,
            url: url,
            name: "",
            iconUrl: networkToAdd?.icon,
            networkSetupType: .noRuntime
        )

        setupChain(with: request)
    }
}
