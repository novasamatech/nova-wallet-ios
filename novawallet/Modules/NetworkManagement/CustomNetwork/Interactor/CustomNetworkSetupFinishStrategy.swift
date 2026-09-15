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

    func createModifyStrategy(networkToModify: ChainModel) -> CustomNetworkSetupFinishStrategy {
        CustomNetworkModifyStrategy(
            repository: repository,
            networkToModify: networkToModify,
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

private extension CustomNetworkSetupFinishStrategy {
    func deriveExplorers(
        from preConfNetwork: ChainModel,
        setUpNetwork: ChainModel
    ) -> [ChainModel.Explorer]? {
        if let newExplorers = setUpNetwork.explorers, !newExplorers.isEmpty {
            newExplorers
        } else {
            preConfNetwork.explorers
        }
    }

    func deriveAssets(
        from preConfNetwork: ChainModel,
        setUpNetwork: ChainModel
    ) -> Set<AssetModel> {
        // we can have only a single asset if it was setup by a user
        if
            let asset = setUpNetwork.assets.first,
            !preConfNetwork.assets.contains(where: { $0.assetId == asset.assetId }) {
            [asset]
        } else {
            preConfNetwork.assets
        }
    }

    func deriveNodes(
        from preConfNetwork: ChainModel,
        setUpNetwork: ChainModel
    ) -> Set<ChainNodeModel> {
        // we can have only a single node if it was setup by a user
        if let node = setUpNetwork.nodes.first, !preConfNetwork.nodes.contains(where: { $0.url == node.url }) {
            Set([node]).union(preConfNetwork.nodes)
        } else {
            preConfNetwork.nodes
        }
    }

    func deriveOptions(
        from preConfNetwork: ChainModel,
        setUpNetwork: ChainModel
    ) -> [LocalChainOptions]? {
        guard let preConfOptions = preConfNetwork.options else {
            return setUpNetwork.options
        }

        let existingOptions = Set(preConfOptions)
        let foundOptions = (setUpNetwork.options ?? []).filter { existingOptions.contains($0) }
        return preConfOptions + foundOptions
    }
}

extension CustomNetworkSetupFinishStrategy {
    func updatePreConfigured(
        network: ChainModel,
        using setUpNetwork: ChainModel
    ) -> ChainModel {
        let explorers = deriveExplorers(from: network, setUpNetwork: setUpNetwork)

        let assets = deriveAssets(from: network, setUpNetwork: setUpNetwork)

        let nodes = deriveNodes(from: network, setUpNetwork: setUpNetwork)

        let options = deriveOptions(from: network, setUpNetwork: setUpNetwork)

        return ChainModel(
            chainId: network.chainId,
            parentId: network.parentId,
            name: setUpNetwork.name,
            assets: assets,
            nodes: nodes,
            nodeSwitchStrategy: network.nodeSwitchStrategy,
            addressPrefix: network.addressPrefix,
            legacyAddressPrefix: network.legacyAddressPrefix,
            types: network.types,
            icon: network.icon,
            options: options,
            externalApis: network.externalApis,
            explorers: explorers,
            order: network.order,
            additional: network.additional,
            syncMode: network.syncMode,
            source: .user,
            connectionMode: network.connectionMode,
            displayPriority: nil
        )
    }

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

            let saveOperation = repository.saveOperation({
                [networkToSave]
            }, {
                []
            })

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
        guard let selectedNode = network.nodes.first else { return }

        output?.didReceive(
            chain: network,
            selectedNode: selectedNode
        )
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

            let saveOperation = repository.saveOperation({
                [readyNetwork]
            }, {
                deleteIds
            })

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

// MARK: - Modify

struct CustomNetworkModifyStrategy: CustomNetworkSetupFinishStrategy {
    let repository: AnyDataProviderRepository<ChainModel>
    let networkToModify: ChainModel
    let operationQueue: OperationQueue

    let chainRegistry: ChainRegistryProtocol

    func handleSetupFinished(
        for network: ChainModel,
        output: CustomNetworkBaseInteractorOutputProtocol?
    ) {
        let networkToSave = updatePreConfigured(
            network: networkToModify,
            using: network
        )

        let saveOperation = repository.saveOperation({
            [networkToSave]
        }, {
            []
        })

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
