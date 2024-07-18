import Foundation
import Operation_iOS

protocol CustomNetworkSetupFinishStrategy {
    func handleSetupFinished(
        for network: ChainModel,
        presenter: CustomNetworkBaseInteractorOutputProtocol?
    )
}

// MARK: - Add new

class CustomNetworkAddNewStrategy: CustomNetworkSetupFinishStrategy {
    private let repository: AnyDataProviderRepository<ChainModel>
    private let operationQueue: OperationQueue

    init(
        repository: AnyDataProviderRepository<ChainModel>,
        operationQueue: OperationQueue
    ) {
        self.repository = repository
        self.operationQueue = operationQueue
    }

    func handleSetupFinished(
        for network: ChainModel,
        presenter: CustomNetworkBaseInteractorOutputProtocol?
    ) {
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
                presenter?.didFinishWorkWithNetwork()
            case .failure:
                presenter?.didReceive(
                    .common(innerError: .dataCorruption)
                )
            }
        }
    }
}

// MARK: - Provide

class CustomNetworkProvideStrategy: CustomNetworkSetupFinishStrategy {
    func handleSetupFinished(
        for network: ChainModel,
        presenter: CustomNetworkBaseInteractorOutputProtocol?
    ) {
        guard let selectedNode = network.nodes.first else { return }

        presenter?.didReceive(
            chain: network,
            selectedNode: selectedNode
        )
    }
}

// MARK: - Edit

class CustomNetworkEditStrategy: CustomNetworkSetupFinishStrategy {
    private let networkToEdit: ChainModel
    private let selectedNode: ChainNodeModel

    private let repository: AnyDataProviderRepository<ChainModel>
    private let operationQueue: OperationQueue

    init(
        networkToEdit: ChainModel,
        selectedNode: ChainNodeModel,
        repository: AnyDataProviderRepository<ChainModel>,
        operationQueue: OperationQueue
    ) {
        self.networkToEdit = networkToEdit
        self.selectedNode = selectedNode
        self.repository = repository
        self.operationQueue = operationQueue
    }

    func handleSetupFinished(
        for network: ChainModel,
        presenter: CustomNetworkBaseInteractorOutputProtocol?
    ) {
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
                presenter?.didFinishWorkWithNetwork()
            case .failure:
                presenter?.didReceive(
                    .common(innerError: .dataCorruption)
                )
            }
        }
    }
}
