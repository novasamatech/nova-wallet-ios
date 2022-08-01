import UIKit
import RobinHood

final class ChangeWatchOnlyInteractor {
    weak var presenter: ChangeWatchOnlyInteractorOutputProtocol?

    let chain: ChainModel
    let wallet: MetaAccountModel
    let settings: SelectedWalletSettings
    let walletOperationFactory: WatchOnlyWalletOperationFactoryProtocol
    let repository: AnyDataProviderRepository<MetaAccountModel>
    let eventCenter: EventCenterProtocol
    let operationQueue: OperationQueue

    init(
        chain: ChainModel,
        wallet: MetaAccountModel,
        settings: SelectedWalletSettings,
        repository: AnyDataProviderRepository<MetaAccountModel>,
        walletOperationFactory: WatchOnlyWalletOperationFactoryProtocol,
        eventCenter: EventCenterProtocol,
        operationQueue: OperationQueue
    ) {
        self.chain = chain
        self.wallet = wallet
        self.settings = settings
        self.repository = repository
        self.walletOperationFactory = walletOperationFactory
        self.eventCenter = eventCenter
        self.operationQueue = operationQueue
    }

    private func performSave(
        newAddress: AccountAddress,
        wallet: MetaAccountModel,
        chain: ChainModel,
        settings: SelectedWalletSettings,
        eventCenter: EventCenterProtocol
    ) {
        let replaceAccountOperation = walletOperationFactory.replaceWatchOnlyAccountOperation(
            for: wallet,
            chain: chain,
            newAddress: newAddress
        )

        let saveOperation: BaseOperation<Void>

        if let selectedWallet = settings.value, selectedWallet.identifier == wallet.identifier {
            saveOperation = ClosureOperation {
                let newWallet = try replaceAccountOperation.extractNoCancellableResultData()
                settings.save(value: newWallet)
                eventCenter.notify(with: SelectedAccountChanged())
            }
        } else {
            saveOperation = repository.saveOperation({
                let newWallet = try replaceAccountOperation.extractNoCancellableResultData()
                return [newWallet]
            }, {
                []
            })
        }

        saveOperation.addDependency(replaceAccountOperation)

        saveOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                do {
                    _ = try saveOperation.extractNoCancellableResultData()
                    self?.eventCenter.notify(with: ChainAccountChanged())
                    self?.presenter?.didSaveAddress(newAddress)
                } catch {
                    self?.presenter?.didReceiveError(error)
                }
            }
        }

        operationQueue.addOperations([replaceAccountOperation, saveOperation], waitUntilFinished: false)
    }
}

extension ChangeWatchOnlyInteractor: ChangeWatchOnlyInteractorInputProtocol {
    func save(address: AccountAddress) {
        performSave(
            newAddress: address,
            wallet: wallet,
            chain: chain,
            settings: settings,
            eventCenter: eventCenter
        )
    }
}
