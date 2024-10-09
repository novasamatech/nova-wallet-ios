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

    func createAddNewStrategy(preConfiguredNetwork: ChainModel? = nil) -> CustomNetworkSetupFinishStrategy {
        CustomNetworkAddNewStrategy(
            repository: repository,
            preConfiguredNetwork: preConfiguredNetwork,
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
    let preConfiguredNetwork: ChainModel?
    let operationQueue: OperationQueue

    let chainRegistry: ChainRegistryProtocol

    func handleSetupFinished(
        for network: ChainModel,
        output: CustomNetworkBaseInteractorOutputProtocol?
    ) {
        processWithCheck(network, output: output) {
            let networkToSave = if let preConfiguredNetwork {
                updatePreConfigured(network: preConfiguredNetwork, using: network)
            } else {
                network
            }

            let saveOperation = repository.saveOperation(
                { [networkToSave] },
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

    private func updatePreConfigured(
        network: ChainModel,
        using setUpNetwork: ChainModel
    ) -> ChainModel {
        let explorers: [ChainModel.Explorer]? = if let newExplorers = setUpNetwork.explorers, !newExplorers.isEmpty {
            newExplorers
        } else {
            network.explorers
        }

        let assets: Set<AssetModel> = {
            if
                let asset = setUpNetwork.assets.first,
                !network.assets.contains(where: { $0.assetId == asset.assetId }) {
                [asset]
            } else {
                network.assets
            }
        }()

        let nodes: Set<ChainNodeModel> = setUpNetwork.nodes.union(network.nodes)

        return ChainModel(
            chainId: network.chainId,
            parentId: network.parentId,
            name: setUpNetwork.name,
            assets: assets,
            nodes: nodes,
            nodeSwitchStrategy: network.nodeSwitchStrategy,
            addressPrefix: network.addressPrefix,
            types: network.types,
            icon: network.icon,
            options: network.options,
            externalApis: network.externalApis,
            explorers: explorers,
            order: network.order,
            additional: network.additional,
            syncMode: network.syncMode,
            source: .user,
            connectionMode: network.connectionMode
        )
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
