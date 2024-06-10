import UIKit
import SubstrateSdk
import SoraFoundation
import RobinHood

final class NetworkDetailsInteractor {
    weak var presenter: NetworkDetailsInteractorOutputProtocol?

    private var chain: ChainModel
    private let connectionFactory: ConnectionFactoryProtocol
    private let chainRegistry: ChainRegistryProtocol
    private let chainSyncService: ChainSyncServiceProtocol
    private let repository: AnyDataProviderRepository<ChainModel>
    private let operationQueue: OperationQueue
    private let nodeMeasureQueue: OperationQueue

    init(
        chain: ChainModel,
        connectionFactory: ConnectionFactoryProtocol,
        chainRegistry: ChainRegistryProtocol,
        chainSyncService: ChainSyncServiceProtocol,
        repository: AnyDataProviderRepository<ChainModel>,
        operationQueue: OperationQueue,
        nodeMeasureQueue: OperationQueue
    ) {
        self.chain = chain
        self.connectionFactory = connectionFactory
        self.chainRegistry = chainRegistry
        self.chainSyncService = chainSyncService
        self.repository = repository
        self.operationQueue = operationQueue
        self.nodeMeasureQueue = nodeMeasureQueue
    }
}

// MARK: NetworkDetailsInteractorInputProtocol

extension NetworkDetailsInteractor: NetworkDetailsInteractorInputProtocol {
    func setup() {
        chainRegistry.chainsSubscribe(
            self,
            runningInQueue: .main
        ) { [weak self] changes in
            let changedChain = changes
                .filter { change in
                    change.item?.chainId == self?.chain.chainId
                }
                .first?
                .item

            guard
                let changedChain,
                self?.chain != changedChain
            else {
                return
            }

            self?.chain = changedChain
            self?.presenter?.didReceive(updatedChain: changedChain)
        }
    }

    func toggleNetwork() {
        let saveOperation = repository.saveOperation({ [weak self] in
            guard let self else { return [] }

            return [chain.byChanging(enabled: !chain.enabled)]
        }, {
            []
        })

        operationQueue.addOperation(saveOperation)
    }

    func toggleConnectionMode() {
        let saveOperation = repository.saveOperation({ [weak self] in
            guard let self else { return [] }

            let newMode: ChainModel.ConnectionMode = if chain.connectionMode == .autoBalanced {
                .manual
            } else {
                .autoBalanced
            }

            return [chain.updatingConnectionMode(for: newMode)]
        }, {
            []
        })

        operationQueue.addOperation(saveOperation)
    }

    func selectNode(with url: String) {
        print(url)
    }
}

// MARK: ConnectionStateSubscription

extension NetworkDetailsInteractor: ConnectionStateSubscription {
    func didReceive(
        state: WebSocketEngine.State,
        for chainId: ChainModel.Id
    ) {
        guard chainId == chain.chainId else { return }

        print(state)
    }
}

// MARK: Private

private extension NetworkDetailsInteractor {
    func measureConnection(for node: ChainNodeModel) {
        let measureOperation: BaseOperation
    }
}
