import UIKit
import RobinHood

final class CreateWatchOnlyInteractor {
    weak var presenter: CreateWatchOnlyInteractorOutputProtocol?

    let repository: WatchOnlyPresetRepositoryProtocol
    let walletOperationFactory: WatchOnlyWalletOperationFactoryProtocol
    let operationQueue: OperationQueue
    let settings: SelectedWalletSettings
    let eventCenter: EventCenterProtocol

    init(
        settings: SelectedWalletSettings,
        walletOperationFactory: WatchOnlyWalletOperationFactoryProtocol,
        repository: WatchOnlyPresetRepositoryProtocol,
        eventCenter: EventCenterProtocol,
        operationQueue: OperationQueue
    ) {
        self.settings = settings
        self.walletOperationFactory = walletOperationFactory
        self.repository = repository
        self.eventCenter = eventCenter
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

    func save(wallet: WatchOnlyWallet) {
        let walletCreateOperation = walletOperationFactory.newWatchOnlyWalletOperation(for: wallet)
        let saveOperation = ClosureOperation { [weak self] in
            let metaAccount = try walletCreateOperation.extractNoCancellableResultData()
            self?.settings.save(value: metaAccount)
            return
        }

        saveOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                do {
                    _ = try saveOperation.extractNoCancellableResultData()
                    self?.settings.setup()
                    self?.eventCenter.notify(with: SelectedAccountChanged())
                    self?.presenter?.didCreateWallet()
                } catch {
                    self?.presenter?.didFailWalletCreation(with: error)
                }
            }
        }

        saveOperation.addDependency(walletCreateOperation)

        operationQueue.addOperations([walletCreateOperation, saveOperation], waitUntilFinished: false)
    }
}
