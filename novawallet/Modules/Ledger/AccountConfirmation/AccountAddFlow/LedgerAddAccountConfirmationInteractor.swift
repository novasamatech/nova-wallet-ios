import Foundation
import SubstrateSdk
import Operation_iOS
import Keystore_iOS

final class LedgerAddAccountConfirmationInteractor: LedgerBaseAccountConfirmationInteractor,
    LedgerAccountConfirmationInteractorInputProtocol {
    let wallet: MetaAccountModel
    let walletRepository: AnyDataProviderRepository<MetaAccountModel>
    let settings: SelectedWalletSettings
    let keystore: KeystoreProtocol
    let eventCenter: EventCenterProtocol

    init(
        wallet: MetaAccountModel,
        chain: ChainModel,
        deviceId: UUID,
        application: LedgerAccountRetrievable,
        requestFactory: StorageRequestFactoryProtocol,
        connection: JSONRPCEngine,
        runtimeService: RuntimeCodingServiceProtocol,
        keystore: KeystoreProtocol,
        walletRepository: AnyDataProviderRepository<MetaAccountModel>,
        settings: SelectedWalletSettings,
        eventCenter: EventCenterProtocol,
        operationQueue: OperationQueue
    ) {
        self.wallet = wallet
        self.settings = settings
        self.eventCenter = eventCenter
        self.keystore = keystore
        self.walletRepository = walletRepository

        super.init(
            chain: chain,
            deviceId: deviceId,
            application: application,
            requestFactory: requestFactory,
            connection: connection,
            runtimeService: runtimeService,
            operationQueue: operationQueue
        )
    }

    override func addAccount(
        for info: LedgerChainAccount.Info,
        chain: ChainModel,
        derivationPath: Data,
        index: UInt32
    ) {
        let chainAccount = ChainAccountModel(
            chainId: chain.chainId,
            accountId: info.accountId,
            publicKey: info.publicKey,
            cryptoType: info.cryptoType.rawValue,
            proxy: nil,
            multisig: nil
        )

        let newAccountItem = wallet.replacingChainAccount(chainAccount)

        let derivationPathSaveOperation = ClosureOperation {
            let tag = KeystoreTagV2.derivationTagForMetaId(
                newAccountItem.metaId,
                accountId: chainAccount.accountId,
                isEthereumBased: chainAccount.isEthereumBased
            )

            try self.keystore.saveKey(derivationPath, with: tag)
        }

        let persistentOperation = walletRepository.saveOperation({
            try derivationPathSaveOperation.extractNoCancellableResultData()
            return [newAccountItem]
        }, { [] })

        persistentOperation.addDependency(derivationPathSaveOperation)

        let settingsSaveOperation: ClosureOperation<Void> = ClosureOperation {
            try persistentOperation.extractNoCancellableResultData()

            if let savedAccountItem = self.settings.value,
               savedAccountItem.identifier == newAccountItem.identifier {
                self.settings.save(value: newAccountItem)
                self.eventCenter.notify(with: SelectedWalletSwitched())
            }

            self.eventCenter.notify(with: ChainAccountChanged())
        }

        settingsSaveOperation.addDependency(persistentOperation)

        settingsSaveOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                do {
                    try settingsSaveOperation.extractNoCancellableResultData()

                    self?.presenter?.didReceiveConfirmation(result: .success(info.accountId), at: index)
                } catch {
                    self?.presenter?.didReceiveConfirmation(result: .failure(error), at: index)
                }
            }
        }

        let operations = [derivationPathSaveOperation, persistentOperation, settingsSaveOperation]

        operationQueue.addOperations(operations, waitUntilFinished: false)
    }
}
