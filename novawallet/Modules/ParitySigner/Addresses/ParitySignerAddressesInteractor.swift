import UIKit
import Operation_iOS
import SubstrateSdk

final class ParitySignerAddressesInteractor {
    weak var presenter: ParitySignerAddressesInteractorOutputProtocol?

    let chainRegistry: ChainRegistryProtocol

    init(chainRegistry: ChainRegistryProtocol) {
        self.chainRegistry = chainRegistry
    }
}

extension ParitySignerAddressesInteractor: ParitySignerAddressesInteractorInputProtocol {
    func setup() {
        chainRegistry.chainsSubscribe(
            self,
            runningInQueue: .main,
            filterStrategy: .hasSubstrateRuntime
        ) { [weak self] changes in
            self?.presenter?.didReceive(chains: changes)
        }
    }

    func confirm() {
        presenter?.didReceiveConfirm(result: .success(()))
    }
}
