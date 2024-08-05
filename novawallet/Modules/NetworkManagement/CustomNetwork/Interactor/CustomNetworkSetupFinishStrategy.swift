import Foundation
import Operation_iOS

struct CustomNetworkSetupFinishStrategyFactory {
    private let chainRegistry: ChainRegistryProtocol
    private let repository: AnyDataProviderRepository<ChainModel>
    private let operationQueue: OperationQueue

    init(
        chainRegistry: ChainRegistryProtocol,
        repository: AnyDataProviderRepository<ChainModel>,
        operationQueue: OperationQueue
    ) {
        self.chainRegistry = chainRegistry
        self.repository = repository
        self.operationQueue = operationQueue
    }

    func createAddNewStrategy() -> CustomNetworkSetupFinishStrategy {
        CustomNetworkAddNewStrategy(
            repository: repository,
            operationQueue: operationQueue,
            chainRegistry: chainRegistry
        )
    }

    func createProvideStrategy() -> CustomNetworkSetupFinishStrategy {
        CustomNetworkProvideStrategy(chainRegistry: chainRegistry)
    }

    func createEditStrategy(
        networkToEdit: ChainModel,
        selectedNode: ChainNodeModel
    ) -> CustomNetworkSetupFinishStrategy {
        CustomNetworkEditStrategy(
            networkToEdit: networkToEdit,
            selectedNode: selectedNode,
            repository: repository,
            operationQueue: operationQueue,
            chainRegistry: chainRegistry
        )
    }
}

protocol CustomNetworkSetupFinishStrategy {
    var chainRegistry: ChainRegistryProtocol { get }

    func handleSetupFinished(
        for network: ChainModel,
        output: CustomNetworkBaseInteractorOutputProtocol?
    )
}

extension CustomNetworkSetupFinishStrategy {
    func processWithCheck(
        _ network: ChainModel,
        output: CustomNetworkBaseInteractorOutputProtocol?,
        successClosure: () -> Void
    ) {
        guard let node = network.nodes.first else {
            return
        }

        switch checkAlreadyExist(network, node) {
        case .success:
            successClosure()
        case let .failure(error):
            output?.didReceive(error)
        }
    }

    private func checkAlreadyExist(
        _ network: ChainModel,
        _ node: ChainNodeModel
    ) -> Result<Void, CustomNetworkBaseInteractorError> {
        if let existingNetwork = chainRegistry.getChain(for: network.chainId) {
            switch existingNetwork.source {
            case .remote:
                return .failure(.alreadyExistRemote(node: node, chain: existingNetwork))
            case .user:
                return .failure(.alreadyExistCustom(node: node, chain: existingNetwork))
            }
        }

        return .success(())
    }
}

// MARK: - Add new

struct CustomNetworkAddNewStrategy: CustomNetworkSetupFinishStrategy {
    let repository: AnyDataProviderRepository<ChainModel>
    let operationQueue: OperationQueue

    let chainRegistry: ChainRegistryProtocol

    func handleSetupFinished(
        for network: ChainModel,
        output: CustomNetworkBaseInteractorOutputProtocol?
    ) {
        processWithCheck(network, output: output) {
            let saveOperation = repository.saveOperation(
                { [network] },
                { [] }
            )

            execute(
                operation: saveOperation,
                inOperationQueue: operationQueue,
                runningCallbackIn: .main
            ) { result in
                switch result {
                case .success:
                    output?.didFinishWorkWithNetwork()
                case .failure:
                    output?.didReceive(
                        .common(innerError: .dataCorruption)
                    )
                }
            }
        }
    }
}

// MARK: - Provide

struct CustomNetworkProvideStrategy: CustomNetworkSetupFinishStrategy {
    let chainRegistry: ChainRegistryProtocol

    func handleSetupFinished(
        for network: ChainModel,
        output: CustomNetworkBaseInteractorOutputProtocol?
    ) {
        processWithCheck(network, output: output) {
            guard let selectedNode = network.nodes.first else { return }

            output?.didReceive(
                chain: network,
                selectedNode: selectedNode
            )
        }
    }
}

// MARK: - Edit

struct CustomNetworkEditStrategy: CustomNetworkSetupFinishStrategy {
    let networkToEdit: ChainModel
    let selectedNode: ChainNodeModel

    let repository: AnyDataProviderRepository<ChainModel>
    let operationQueue: OperationQueue

    let chainRegistry: ChainRegistryProtocol

    func handleSetupFinished(
        for network: ChainModel,
        output: CustomNetworkBaseInteractorOutputProtocol?
    ) {
        processWithCheck(network, output: output) {
            var readyNetwork = network

            if network.chainId == networkToEdit.chainId {
                var nodesToAdd = networkToEdit.nodes

                if !network.nodes.contains(where: { $0.url == selectedNode.url }) {
                    nodesToAdd.remove(selectedNode)
                }

                readyNetwork = network.adding(nodes: nodesToAdd)
            }

            let deleteIds = network.chainId != networkToEdit.chainId
                ? [networkToEdit.chainId]
                : []

            let saveOperation = repository.saveOperation(
                { [readyNetwork] },
                { deleteIds }
            )

            execute(
                operation: saveOperation,
                inOperationQueue: operationQueue,
                runningCallbackIn: .main
            ) { result in
                switch result {
                case .success:
                    output?.didFinishWorkWithNetwork()
                case .failure:
                    output?.didReceive(
                        .common(innerError: .dataCorruption)
                    )
                }
            }
        }
    }
}
