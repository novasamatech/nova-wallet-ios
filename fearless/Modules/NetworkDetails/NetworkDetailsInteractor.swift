import UIKit

final class NetworkDetailsInteractor {
    weak var presenter: NetworkDetailsInteractorOutputProtocol!

    let chainModel: ChainModel
    let chainRegistry: ChainRegistryProtocol

    init(
        chainModel: ChainModel,
        chainRegistry: ChainRegistryProtocol
    ) {
        self.chainModel = chainModel
        self.chainRegistry = chainRegistry
    }

    private func provideSelectedConnection() {
        let connection = chainRegistry.getConnection(for: chainModel.chainId)
        presenter.didReceiveSelectedConnection(connection)
    }

    private func provideAutoSelectNodesState() {
        // TODO:
        presenter.didReceiveAutoSelectNodes(true)
    }
}

extension NetworkDetailsInteractor: NetworkDetailsInteractorInputProtocol {
    func setup() {
        provideAutoSelectNodesState()
        provideSelectedConnection()
    }

    func toggleAutoSelectNodes(isOn: Bool) {
        // TODO:
        presenter.didReceiveAutoSelectNodes(isOn)
    }
}
