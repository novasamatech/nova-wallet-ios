import UIKit
import NovaCrypto
import Operation_iOS
import Foundation_iOS

final class WalletMigrateAcceptInteractor {
    weak var presenter: WalletMigrateAcceptInteractorOutputProtocol?

    let sessionManager: SecureSessionManaging
    let cloudBackupSyncService: CloudBackupSyncServiceProtocol
    let walletMigrationService: WalletMigrationServiceProtocol
    let metaAccountOperationFactory: MetaAccountOperationFactoryProtocol
    let mnemonicFactory: IRMnemonicCreatorProtocol
    let operationQueue: OperationQueue
    let settings: SelectedWalletSettings
    let eventCenter: EventCenterProtocol
    let logger: LoggerProtocol

    private var channel: WalletMigrationDestination

    init(
        startMessage: WalletMigrationMessage.Start,
        cloudBackupSyncService: CloudBackupSyncServiceProtocol,
        walletMigrationService: WalletMigrationServiceProtocol,
        sessionManager: SecureSessionManaging,
        settings: SelectedWalletSettings,
        metaAccountOperationFactory: MetaAccountOperationFactoryProtocol,
        mnemonicFactory: IRMnemonicCreatorProtocol,
        operationQueue: OperationQueue,
        eventCenter: EventCenterProtocol,
        logger: LoggerProtocol
    ) {
        self.sessionManager = sessionManager
        self.cloudBackupSyncService = cloudBackupSyncService
        self.walletMigrationService = walletMigrationService
        self.settings = settings
        self.metaAccountOperationFactory = metaAccountOperationFactory
        self.mnemonicFactory = mnemonicFactory
        self.operationQueue = operationQueue
        channel = WalletMigrationDestination.createFrom(originScheme: startMessage.originScheme)
        self.eventCenter = eventCenter
        self.logger = logger
    }
}

private extension WalletMigrateAcceptInteractor {
    func initiateSession() {
        presenter?.didRequestMigration(from: channel.originScheme)
    }

    func acceptSession() {
        do {
            let publicKey = try sessionManager.startSession()

            try channel.accept(with: .init(destinationPublicKey: publicKey))
        } catch {
            logger.error("Can't start session")
        }
    }

    func completeSession(with model: WalletMigrationMessage.Complete) {
        do {
            let decryptor = try sessionManager.deriveCryptor(peerPubKey: model.originPublicKey)

            let entropy = try decryptor.decrypt(model.encryptedData)

            let walletName = model.name ?? "\(channel.originScheme.capitalized) Wallet"

            let request = MetaAccountCreationRequest(
                username: walletName,
                derivationPath: "",
                ethereumDerivationPath: DerivationPathConstants.defaultEthereum,
                cryptoType: .sr25519
            )

            let mnemonic = try mnemonicFactory.mnemonic(fromEntropy: entropy)

            completeWalletCreation(from: request, mnemonic: mnemonic)
        } catch {
            logger.error("Can't complete wallet import \(error)")
        }
    }

    func completeWalletCreation(from request: MetaAccountCreationRequest, mnemonic: IRMnemonicProtocol) {
        let importOperation = metaAccountOperationFactory.newSecretsMetaAccountOperation(
            request: request,
            mnemonic: mnemonic
        )

        let saveOperation: ClosureOperation<MetaAccountModel> = ClosureOperation { [weak self] in
            let accountItem = try importOperation.extractNoCancellableResultData()
            self?.settings.save(value: accountItem)

            return accountItem
        }

        saveOperation.addDependency(importOperation)

        let wrapper = CompoundOperationWrapper(targetOperation: saveOperation, dependencies: [importOperation])

        execute(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            runningCallbackIn: .main
        ) { [weak self] result in
            guard let self else {
                return
            }

            switch result {
            case .success:
                settings.setup()
                eventCenter.notify(with: SelectedWalletSwitched())
                eventCenter.notify(with: NewWalletImported())
                presenter?.didCompleteMigration()
            case let .failure(error):
                presenter?.didFailMigration(with: error)
            }
        }
    }

    func handle(message: WalletMigrationMessage) {
        switch message {
        case let .start(model):
            channel = WalletMigrationDestination.createFrom(originScheme: model.originScheme)

            initiateSession()
        case let .complete(model):
            completeSession(with: model)
        case .accepted:
            logger.debug("Skipping accept event as we act as destination")
        }
    }

    func subscribeCloudBackupState() {
        cloudBackupSyncService.subscribeState(
            self,
            notifyingIn: .main
        ) { [weak self] state in
            self?.presenter?.didReceiveCloudBackup(state: state)
        }
    }
}

extension WalletMigrateAcceptInteractor: WalletMigrateAcceptInteractorInputProtocol {
    func setup() {
        subscribeCloudBackupState()
        initiateSession()

        walletMigrationService.addObserver(self)
    }

    func accept() {
        acceptSession()
    }
}

extension WalletMigrateAcceptInteractor: WalletMigrationObserver {
    func didReceiveMigration(message: WalletMigrationMessage) {
        handle(message: message)
    }
}
