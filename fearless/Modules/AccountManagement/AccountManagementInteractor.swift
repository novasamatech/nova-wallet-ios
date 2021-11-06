import UIKit
import RobinHood
import SoraKeystore

final class AccountManagementInteractor {
    weak var presenter: AccountManagementInteractorOutputProtocol?

    let walletRepository: AnyDataProviderRepository<ManagedMetaAccountModel>
    let chainRepository: AnyDataProviderRepository<ChainModel>
    let settings: SelectedWalletSettings
    let operationManager: OperationManagerProtocol
    let eventCenter: EventCenterProtocol
    let keystore: KeystoreProtocol

    private lazy var saveScheduler = Scheduler(with: self, callbackQueue: .main)
    private var saveInterval: TimeInterval
    private var pendingName: String?
    private var pendingWalletId: String?

    init(
        walletRepository: AnyDataProviderRepository<ManagedMetaAccountModel>,
        chainRepository: AnyDataProviderRepository<ChainModel>,
        operationManager: OperationManagerProtocol,
        settings: SelectedWalletSettings,
        eventCenter: EventCenterProtocol,
        keystore: KeystoreProtocol,
        saveInterval: TimeInterval = 2.0
    ) {
        self.walletRepository = walletRepository
        self.chainRepository = chainRepository
        self.operationManager = operationManager
        self.settings = settings
        self.eventCenter = eventCenter
        self.keystore = keystore
        self.saveInterval = saveInterval
    }

    // MARK: - Fetching functions

    private func fetchChains() {
        let operation = chainRepository.fetchAllOperation(with: RepositoryFetchOptions())

        operation.completionBlock = {
            DispatchQueue.main.async {
                do {
                    let chains = try operation.extractNoCancellableResultData()

                    let chainsById: [ChainModel.Id: ChainModel] = chains.reduce(into: [:]) { result, chain in
                        result[chain.chainId] = chain
                    }

                    self.presenter?.didReceiveChains(.success(chainsById))
                } catch {
                    self.presenter?.didReceiveChains(.failure(error))
                }
            }
        }
        operationManager.enqueue(operations: [operation], in: .transient)
    }

    private func fetchWallet(with walletId: String) {
        let operation = walletRepository.fetchOperation(
            by: walletId,
            options: RepositoryFetchOptions()
        )

        operation.completionBlock = {
            DispatchQueue.main.async {
                do {
                    let wallet = try operation.extractNoCancellableResultData()?.info
                    self.presenter?.didReceiveWallet(.success(wallet))
                } catch {
                    self.presenter?.didReceiveWallet(.failure(error))
                }
            }
        }

        operationManager.enqueue(operations: [operation], in: .transient)
    }

    // MARK: - Result handling functions

    private func handleSaveOperationResult(
        result: Result<Void, Error>?,
        newName: String,
        walletId: String
    ) {
        guard let result = result else {
            presenter?.didSaveWalletName(.failure(BaseOperationError.parentOperationCancelled))
            return
        }

        switch result {
        case .success:
            if let selectedWallet = settings.value,
               selectedWallet.identifier == walletId {
                settings.setup()
                eventCenter.notify(with: SelectedUsernameChanged())
            }

            presenter?.didSaveWalletName(.success(newName))

        case let .failure(error):
            presenter?.didSaveWalletName(.failure(error))
        }
    }

    // MARK: - Actions

    private func performWalletNameSave(newName: String, for walletId: String) {
        let fetchOperation = walletRepository.fetchOperation(
            by: walletId, options: RepositoryFetchOptions()
        )

        let saveOperation = walletRepository.saveOperation({
            guard let currentItem = try fetchOperation
                .extractResultData(throwing: BaseOperationError.parentOperationCancelled)
            else {
                throw AccountInfoInteractorError.missingAccount
            }

            guard currentItem.info.name != newName else {
                return []
            }

            let newInfo = currentItem.info.replacingName(with: newName)
            let changedItem = currentItem.replacingInfo(newInfo)

            return [changedItem]
        }, { [] })

        saveOperation.addDependency(fetchOperation)

        saveOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                self?.handleSaveOperationResult(
                    result: saveOperation.result,
                    newName: newName,
                    walletId: walletId
                )
            }
        }

        operationManager.enqueue(operations: [fetchOperation, saveOperation], in: .transient)
    }

    private func performChangeFinalizationIfNeeded() {
        guard let name = pendingName,
              let walletId = pendingWalletId else { return }

        pendingName = nil
        pendingWalletId = nil

        performWalletNameSave(newName: name, for: walletId)
    }
}

// MARK: - AccountManagementInteractorInputProtocol

extension AccountManagementInteractor: AccountManagementInteractorInputProtocol {
    func setup(walletId: String) {
        fetchWallet(with: walletId)
        fetchChains()
    }

    func save(name: String, walletId: String) {
        let shouldScheduleSave = pendingName == nil

        pendingName = name
        pendingWalletId = walletId

        if shouldScheduleSave {
            saveScheduler.notifyAfter(saveInterval)
        }
    }

    func flushPendingName() {
        performChangeFinalizationIfNeeded()
    }

    func requestExportOptions(metaAccount: MetaAccountModel, chain: ChainModel) {
        do {
            guard let accountResponse = metaAccount.fetch(for: chain.accountRequest()) else {
                throw ChainAccountFetchingError.accountNotExists
            }

            let accountId = metaAccount.fetchChainAccountId(for: chain.accountRequest())

            var options: [ExportOption] = [.keystore]

            let entropyTag = KeystoreTagV2.entropyTagForMetaId(
                metaAccount.metaId,
                accountId: accountId
            )
            if try keystore.checkKey(for: entropyTag) {
                options.append(.mnemonic)
            }

            let seedTag = chain.isEthereumBased ?
                KeystoreTagV2.ethereumSeedTagForMetaId(metaAccount.metaId, accountId: accountId) :
                KeystoreTagV2.substrateSeedTagForMetaId(metaAccount.metaId, accountId: accountId)
            let hasSeed = try keystore.checkKey(for: seedTag)
            if hasSeed || accountResponse.cryptoType.supportsSeedFromSecretKey {
                options.append(.seed)
            }

            presenter?.didReceive(
                exportOptionsResult: .success(options),
                metaAccount: metaAccount,
                chain: chain
            )
        } catch {
            presenter?.didReceive(
                exportOptionsResult: .failure(error),
                metaAccount: metaAccount,
                chain: chain
            )
        }
    }
}

// MARK: - SchedulerDelegate

extension AccountManagementInteractor: SchedulerDelegate {
    func didTrigger(scheduler _: SchedulerProtocol) {
        performChangeFinalizationIfNeeded()
    }
}
