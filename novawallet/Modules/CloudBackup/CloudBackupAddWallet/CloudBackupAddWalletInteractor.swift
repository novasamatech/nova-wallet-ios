import UIKit
import RobinHood
import IrohaCrypto

final class CloudBackupAddWalletInteractor {
    weak var presenter: CloudBackupAddWalletInteractorOutputProtocol?

    let walletOperationFactory: MetaAccountOperationFactoryProtocol
    let walletSettings: SelectedWalletSettings
    let eventCenter: EventCenterProtocol
    let operationQueue: OperationQueue

    let cancellableStore = CancellableCallStore()

    init(
        walletOperationFactory: MetaAccountOperationFactoryProtocol,
        walletSettings: SelectedWalletSettings,
        eventCenter: EventCenterProtocol,
        operationQueue: OperationQueue
    ) {
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
            let mnemonic = try IRMnemonicCreator().randomMnemonic(.entropy128)
            let request = MetaAccountCreationRequest(
                username: name,
                derivationPath: "",
                ethereumDerivationPath: "",
                cryptoType: .sr25519
            )

            let walletOperation = walletOperationFactory.newSecretsMetaAccountOperation(
                request: request,
                mnemonic: mnemonic
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
                    self?.eventCenter.notify(with: SelectedAccountChanged())
                    self?.eventCenter.notify(with: AccountsChanged(method: .manually))
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
