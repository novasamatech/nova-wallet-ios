import UIKit
import Operation_iOS

final class ManualBackupKeyListInteractor {
    weak var presenter: ManualBackupKeyListInteractorOutputProtocol?

    private let chainRegistry: ChainRegistryProtocol

    init(chainRegistry: ChainRegistryProtocol) {
        self.chainRegistry = chainRegistry
    }
}

extension ManualBackupKeyListInteractor: ManualBackupKeyListInteractorInputProtocol {
    func setup() {
        subscribeOnChains()
    }
}

private extension ManualBackupKeyListInteractor {
    func subscribeOnChains() {
        chainRegistry.chainsSubscribe(
            self,
            runningInQueue: .main
        ) { [weak self] changes in
            self?.presenter?.didReceive(changes)
        }
    }
}
