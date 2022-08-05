import UIKit
import RobinHood

final class ParitySignerAddConfirmInteractor {
    weak var presenter: ParitySignerAddConfirmInteractorOutputProtocol?

    let substrateAccountId: AccountId
    let walletOperationFactory: ParitySignerWalletOperationFactoryProtocol
    let operationQueue: OperationQueue
    let settings: SelectedWalletSettings
    let eventCenter: EventCenterProtocol

    init(
        substrateAccountId: AccountId,
        settings: SelectedWalletSettings,
        walletOperationFactory: ParitySignerWalletOperationFactoryProtocol,
        eventCenter: EventCenterProtocol,
        operationQueue: OperationQueue
    ) {
        self.substrateAccountId = substrateAccountId
        self.settings = settings
        self.walletOperationFactory = walletOperationFactory
        self.eventCenter = eventCenter
        self.operationQueue = operationQueue
    }
}

extension ParitySignerAddConfirmInteractor: ParitySignerAddConfirmInteractorInputProtocol {
    func save(with walletName: String) {
        let request = ParitySignerWallet(substrateAccountId: substrateAccountId, name: walletName)
        let walletCreateOperation = walletOperationFactory.newParitySignerWallet(for: request)
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
                    self?.presenter?.didReceive(error: error)
                }
            }
        }

        saveOperation.addDependency(walletCreateOperation)

        operationQueue.addOperations([walletCreateOperation, saveOperation], waitUntilFinished: false)
    }
}
