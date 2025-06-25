import UIKit
import Operation_iOS

final class ParitySignerUpdateWalletInteractor {
    weak var presenter: ParitySignerAddressesInteractorOutputProtocol?

    let wallet: MetaAccountModel
    let walletUpdate: PolkadotVaultWalletUpdate
    let walletSettings: SelectedWalletSettings
    let walletOperationFactory: ParitySignerWalletOperationFactoryProtocol
    let walletRepository: AnyDataProviderRepository<MetaAccountModel>
    let chainRegistry: ChainRegistryProtocol
    let eventCenter: EventCenterProtocol
    let operationQueue: OperationQueue

    let updateStore = CancellableCallStore()

    init(
        wallet: MetaAccountModel,
        walletUpdate: PolkadotVaultWalletUpdate,
        walletSettings: SelectedWalletSettings,
        walletOperationFactory: ParitySignerWalletOperationFactoryProtocol,
        walletRepository: AnyDataProviderRepository<MetaAccountModel>,
        chainRegistry: ChainRegistryProtocol,
        eventCenter: EventCenterProtocol,
        operationQueue: OperationQueue
    ) {
        self.wallet = wallet
        self.walletUpdate = walletUpdate
        self.walletSettings = walletSettings
        self.walletOperationFactory = walletOperationFactory
        self.walletRepository = walletRepository
        self.chainRegistry = chainRegistry
        self.eventCenter = eventCenter
        self.operationQueue = operationQueue
    }
}

private extension ParitySignerUpdateWalletInteractor {
    func updateWalletWrapper() -> CompoundOperationWrapper<Void> {
        let walletUpdateOperation = walletOperationFactory.updateHardwareWallet(for: wallet, update: walletUpdate)

        let saveOperation = walletRepository.saveOperation({
            let updatedWallet = try walletUpdateOperation.extractNoCancellableResultData()
            return [updatedWallet]
        }, { [] })

        saveOperation.addDependency(walletUpdateOperation)

        let isCurrentWallet = walletSettings.value.metaId == wallet.metaId

        let settingsSaveOperation: ClosureOperation<Void> = ClosureOperation {
            try saveOperation.extractNoCancellableResultData()

            if isCurrentWallet {
                self.walletSettings.setup()
                self.eventCenter.notify(with: SelectedWalletSwitched())
            }

            self.eventCenter.notify(with: ChainAccountChanged())
        }

        settingsSaveOperation.addDependency(saveOperation)

        return CompoundOperationWrapper(
            targetOperation: settingsSaveOperation,
            dependencies: [walletUpdateOperation, saveOperation]
        )
    }
}

extension ParitySignerUpdateWalletInteractor: ParitySignerAddressesInteractorInputProtocol {
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
        guard !updateStore.hasCall else {
            return
        }

        let wrapper = updateWalletWrapper()

        executeCancellable(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            backingCallIn: updateStore,
            runningCallbackIn: .main
        ) { [weak self] result in
            self?.presenter?.didReceiveConfirm(result: result)
        }
    }
}
