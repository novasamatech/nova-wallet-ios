import UIKit

final class TokensAddSelectNetworkInteractor {
    weak var presenter: TokensAddSelectNetworkInteractorOutputProtocol?

    let chainRegistry: ChainRegistryProtocol

    init(chainRegistry: ChainRegistryProtocol) {
        self.chainRegistry = chainRegistry
    }

    private func subscribeChains() {
        chainRegistry.chainsSubscribe(
            self,
            runningInQueue: .main
        ) { [weak self] changes in
            self?.presenter?.didReceiveChainModel(changes: changes)
        }
    }
}

extension TokensAddSelectNetworkInteractor: TokensAddSelectNetworkInteractorInputProtocol {
    func setup() {
        subscribeChains()
    }
}
