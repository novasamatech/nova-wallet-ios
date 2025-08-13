import Foundation
import Keystore_iOS
import Operation_iOS

final class GenericLedgerWalletConfirmInteractor: BaseLedgerWalletConfirmInteractor {
    let model: PolkadotLedgerWalletModel
    let walletOperationFactory: GenericLedgerWalletOperationFactoryProtocol
    let operationQueue: OperationQueue
    let settings: SelectedWalletSettings
    let keystore: KeystoreProtocol
    let eventCenter: EventCenterProtocol

    let cancellableStore = CancellableCallStore()

    init(
        model: PolkadotLedgerWalletModel,
        walletOperationFactory: GenericLedgerWalletOperationFactoryProtocol,
        settings: SelectedWalletSettings,
        eventCenter: EventCenterProtocol,
        keystore: KeystoreProtocol,
        operationQueue: OperationQueue
    ) {
        self.model = model
        self.walletOperationFactory = walletOperationFactory
        self.settings = settings
        self.keystore = keystore
        self.eventCenter = eventCenter
        self.operationQueue = operationQueue
    }
}

extension GenericLedgerWalletConfirmInteractor: LedgerWalletConfirmInteractorInputProtocol {
    func save(with walletName: String) {
        guard !cancellableStore.hasCall else {
            return
        }

        let saveOperation = walletOperationFactory.createSaveOperation(
            for: model,
            name: walletName,
            keystore: keystore,
            settings: settings
        )

        execute(
            operation: saveOperation,
            inOperationQueue: operationQueue,
            backingCallIn: cancellableStore,
            runningCallbackIn: .main
        ) { [weak self] result in
            guard let self else {
                return
            }

            switch result {
            case .success:
                self.eventCenter.notify(with: SelectedWalletSwitched())
                self.eventCenter.notify(with: NewWalletCreated())

                self.presenter?.didCreateWallet()
            case let .failure(error):
                self.presenter?.didReceive(error: error)
            }
        }
    }
}
