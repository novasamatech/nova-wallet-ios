import UIKit
import Operation_iOS

final class PVAddConfirmInteractor {
    weak var presenter: PVAddConfirmInteractorOutputProtocol?

    let account: PolkadotVaultAccount
    let type: ParitySignerType
    let pvWalletOperationFactory: ParitySignerWalletOperationFactoryProtocol
    let walletOperationFactory: MetaAccountOperationFactoryProtocol
    let operationQueue: OperationQueue
    let settings: SelectedWalletSettings
    let eventCenter: EventCenterProtocol

    init(
        account: PolkadotVaultAccount,
        type: ParitySignerType,
        settings: SelectedWalletSettings,
        pvWalletOperationFactory: ParitySignerWalletOperationFactoryProtocol,
        walletOperationFactory: MetaAccountOperationFactoryProtocol,
        eventCenter: EventCenterProtocol,
        operationQueue: OperationQueue
    ) {
        self.account = account
        self.type = type
        self.settings = settings
        self.pvWalletOperationFactory = pvWalletOperationFactory
        self.walletOperationFactory = walletOperationFactory
        self.eventCenter = eventCenter
        self.operationQueue = operationQueue
    }
}

// MARK: - Private

private extension PVAddConfirmInteractor {
    func createPVWalletWrapper(
        with walletName: String,
        address: AccountAddress
    ) -> CompoundOperationWrapper<Void> {
        OperationCombiningService.compoundNonOptionalWrapper(operationQueue: operationQueue) {
            let request = ParitySignerWallet(
                substrateAccountId: try address.toAccountId(),
                name: walletName
            )
            let walletCreateOperation = self.pvWalletOperationFactory.newHardwareWallet(
                for: request,
                type: self.type
            )
            let saveOperation = ClosureOperation { [weak self] in
                let metaAccount = try walletCreateOperation.extractNoCancellableResultData()
                self?.settings.save(value: metaAccount)
                return
            }

            saveOperation.addDependency(walletCreateOperation)

            return CompoundOperationWrapper(
                targetOperation: saveOperation,
                dependencies: [walletCreateOperation]
            )
        }
    }

    func createSecretsWalletWrapper(
        with name: String,
        pvSecret: PolkadotVaultSecret
    ) -> CompoundOperationWrapper<Void> {
        let walletImportOperation: BaseOperation<MetaAccountModel> = switch pvSecret.secret {
        case let .keypair(publicKey, secretKey):
            walletOperationFactory.newSecretsMetaAccountOperation(
                request: MetaAccountImportKeypairRequest(
                    secretKey: secretKey,
                    publicKey: publicKey,
                    username: name,
                    derivationPath: "",
                    cryptoType: .sr25519
                )
            )
        case let .seed(seed):
            walletOperationFactory.newSecretsMetaAccountOperation(
                request: MetaAccountImportSeedRequest(
                    seed: seed.toHex(),
                    username: name,
                    derivationPath: "",
                    cryptoType: .sr25519
                )
            )
        }
        let saveOperation = ClosureOperation { [weak self] in
            let metaAccount = try walletImportOperation.extractNoCancellableResultData()
            self?.settings.save(value: metaAccount)
            return
        }

        saveOperation.addDependency(walletImportOperation)

        return CompoundOperationWrapper(
            targetOperation: saveOperation,
            dependencies: [walletImportOperation]
        )
    }
}

// MARK: - PVAddConfirmInteractorInputProtocol

extension PVAddConfirmInteractor: PVAddConfirmInteractorInputProtocol {
    func save(with walletName: String) {
        let wrapper: CompoundOperationWrapper<Void>

        switch account {
        case let .public(vaultAddress):
            wrapper = createPVWalletWrapper(
                with: walletName,
                address: vaultAddress.address
            )
        case let .private(accountAddress, secret):
            wrapper = createSecretsWalletWrapper(
                with: walletName,
                pvSecret: secret
            )
        }

        execute(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case .success:
                self?.settings.setup()
                self?.eventCenter.notify(with: SelectedWalletSwitched())
                self?.eventCenter.notify(with: NewWalletCreated())
                self?.presenter?.didCreateWallet()
            case let .failure(error):
                self?.presenter?.didReceive(error: error)
            }
        }
    }
}
