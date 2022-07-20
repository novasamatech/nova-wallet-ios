import UIKit

final class CreateWatchOnlyInteractor {
    weak var presenter: CreateWatchOnlyInteractorOutputProtocol?

    let repository: WatchOnlyPresetRepositoryProtocol
    let operationQueue: OperationQueue

    init(repository: WatchOnlyPresetRepositoryProtocol, operationQueue: OperationQueue) {
        self.repository = repository
        self.operationQueue = operationQueue
    }

    private func provideWatchOnlyPresets() {
        let wrapper = repository.fetchPresetsWrapper()

        wrapper.targetOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                let wallets = try? wrapper.targetOperation.extractNoCancellableResultData()
                self?.presenter?.didReceivePreset(wallets: wallets ?? [])
            }
        }

        operationQueue.addOperations(wrapper.allOperations, waitUntilFinished: false)
    }
}

extension CreateWatchOnlyInteractor: CreateWatchOnlyInteractorInputProtocol {
    func setup() {
        provideWatchOnlyPresets()
    }

    func save(wallet _: WatchOnlyWallet) {}
}
