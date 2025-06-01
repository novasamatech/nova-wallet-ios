import UIKit
import Operation_iOS
import Keystore_iOS

final class GenericLedgerAddEvmInteractor {
    weak var presenter: GenericLedgerAddEvmInteractorOutputProtocol?

    let wallet: MetaAccountModel
    let accountFetchFactory: GenericLedgerAccountFetchFactoryProtocol
    let walletOperationFactory: GenericLedgerWalletOperationFactoryProtocol
    let walletRepository: AnyDataProviderRepository<MetaAccountModel>
    let keystore: KeystoreProtocol
    let walletSettings: SelectedWalletSettings
    let eventCenter: EventCenterProtocol
    let operationQueue: OperationQueue

    let fetchStore = CancellableCallStore()
    let updateStore = CancellableCallStore()

    init(
        wallet: MetaAccountModel,
        accountFetchFactory: GenericLedgerAccountFetchFactoryProtocol,
        walletOperationFactory: GenericLedgerWalletOperationFactoryProtocol,
        walletRepository: AnyDataProviderRepository<MetaAccountModel>,
        keystore: KeystoreProtocol,
        walletSettings: SelectedWalletSettings,
        eventCenter: EventCenterProtocol,
        operationQueue: OperationQueue
    ) {
        self.wallet = wallet
        self.accountFetchFactory = accountFetchFactory
        self.walletOperationFactory = walletOperationFactory
        self.walletRepository = walletRepository
        self.keystore = keystore
        self.walletSettings = walletSettings
        self.eventCenter = eventCenter
        self.operationQueue = operationQueue
    }

    deinit {
        performUpdateCancellation()
        fetchStore.cancel()
    }
}

private extension GenericLedgerAddEvmInteractor {
    func updateWalletWrapper(
        dependingOn modelOperation: BaseOperation<LedgerEvmAccountResponse>
    ) -> CompoundOperationWrapper<Void> {
        let updateWrapper = OperationCombiningService<Void>.compoundNonOptionalWrapper(
            operationQueue: operationQueue
        ) {
            let model = try modelOperation.extractNoCancellableResultData()

            return self.walletOperationFactory.createUpdateEvmWrapper(
                for: model,
                wallet: self.wallet,
                keystore: self.keystore,
                repository: self.walletRepository
            )
        }

        let isCurrentWallet = walletSettings.value.metaId == wallet.metaId

        let settingsSaveOperation: ClosureOperation<Void> = ClosureOperation {
            try updateWrapper.targetOperation.extractNoCancellableResultData()

            if isCurrentWallet {
                self.walletSettings.setup()
                self.eventCenter.notify(with: SelectedWalletSwitched())
            }

            self.eventCenter.notify(with: ChainAccountChanged())
        }

        settingsSaveOperation.addDependency(updateWrapper.targetOperation)

        return updateWrapper.insertingTail(operation: settingsSaveOperation)
    }

    func performUpdateCancellation() {
        if updateStore.hasCall {
            updateStore.cancel()
            accountFetchFactory.cancelConfirmationRequests()
        }
    }
}

extension GenericLedgerAddEvmInteractor: GenericLedgerAddEvmInteractorInputProtocol {
    func loadAccounts(at index: UInt32) {
        fetchStore.cancel()

        let wrapper = accountFetchFactory.createAccountModel(
            for: [.substrate, .evm],
            index: index,
            shouldConfirm: false
        )

        executeCancellable(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            backingCallIn: fetchStore,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(model):
                self?.presenter?.didReceive(account: model)
            case let .failure(error):
                self?.presenter?.didReceive(error: .accountFailed(error))
            }
        }
    }

    func confirm(index: UInt32) {
        performUpdateCancellation()

        let fetchWrapper = accountFetchFactory.createEvmModel(index: index, shouldConfirm: true)

        let updateWrapper = updateWalletWrapper(dependingOn: fetchWrapper.targetOperation)

        updateWrapper.addDependency(wrapper: fetchWrapper)

        let totalWrapper = updateWrapper.insertingHead(operations: fetchWrapper.allOperations)

        executeCancellable(
            wrapper: totalWrapper,
            inOperationQueue: operationQueue,
            backingCallIn: updateStore,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case .success:
                self?.presenter?.didUpdateWallet()
            case let .failure(error):
                self?.presenter?.didReceive(error: .updateFailed(error, index))
            }
        }
    }

    func cancelConfirmation() {
        performUpdateCancellation()
    }
}
