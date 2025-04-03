import UIKit
import Operation_iOS
import NovaCrypto

final class CloudBackupAddWalletInteractor {
    weak var presenter: CloudBackupAddWalletInteractorOutputProtocol?

    let walletRequestFactory: WalletCreationRequestFactoryProtocol
    let walletOperationFactory: MetaAccountOperationFactoryProtocol
    let walletSettings: SelectedWalletSettings
    let eventCenter: EventCenterProtocol
    let operationQueue: OperationQueue

    let cancellableStore = CancellableCallStore()

    init(
        walletRequestFactory: WalletCreationRequestFactoryProtocol,
        walletOperationFactory: MetaAccountOperationFactoryProtocol,
        walletSettings: SelectedWalletSettings,
        eventCenter: EventCenterProtocol,
        operationQueue: OperationQueue
    ) {
        self.walletRequestFactory = walletRequestFactory
        self.walletOperationFactory = walletOperationFactory
        self.walletSettings = walletSettings
        self.eventCenter = eventCenter
        self.operationQueue = operationQueue
    }
}

extension CloudBackupAddWalletInteractor: CloudBackupAddWalletInteractorInputProtocol {
    func createWallet(for name: String) {
        guard !cancellableStore.hasCall else {
            return
        }

        do {
            let request = try walletRequestFactory.createNewWalletRequest(for: name)

            let walletOperation = walletOperationFactory.newSecretsMetaAccountOperation(
                request: request.walletRequest,
                mnemonic: request.mnemonic
            )

            let saveOperation = ClosureOperation {
                let wallet = try walletOperation.extractNoCancellableResultData()
                self.walletSettings.save(value: wallet)
            }

            saveOperation.addDependency(walletOperation)

            let wrapper = CompoundOperationWrapper(
                targetOperation: saveOperation,
                dependencies: [walletOperation]
            )

            executeCancellable(
                wrapper: wrapper,
                inOperationQueue: operationQueue,
                backingCallIn: cancellableStore,
                runningCallbackIn: .main
            ) { [weak self] result in
                switch result {
                case .success:
                    self?.walletSettings.setup()
                    self?.eventCenter.notify(with: SelectedWalletSwitched())
                    self?.eventCenter.notify(with: NewWalletCreated())
                    self?.presenter?.didCreateWallet()

                case let .failure(error):
                    self?.presenter?.didReceive(error: .walletSave(error))
                }
            }
        } catch {
            presenter?.didReceive(error: .mnemonicGenerate(error))
        }
    }
}
