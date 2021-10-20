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
}

extension NetworkDetailsInteractor: NetworkDetailsInteractorInputProtocol {
    func setup() {
        provideSelectedConnection()
    }
}
