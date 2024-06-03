import UIKit
import RobinHood
import SoraKeystore
import IrohaCrypto

enum AccountManagementError: Error {
    case missingAccount
}

final class AccountManagementInteractor {
    weak var presenter: AccountManagementInteractorOutputProtocol?

    let cloudBackupSyncFacade: CloudBackupSyncFacadeProtocol
    let walletCreationRequestFactory: WalletCreationRequestFactoryProtocol
    let walletRepository: AnyDataProviderRepository<ManagedMetaAccountModel>
    let accountOperationFactory: MetaAccountOperationFactoryProtocol
    let chainRepository: AnyDataProviderRepository<ChainModel>
    let settings: SelectedWalletSettings
    let operationQueue: OperationQueue
    let eventCenter: EventCenterProtocol
    let chainsFilter: AccountManagementFilterProtocol
    let keystore: KeystoreProtocol

    private lazy var saveScheduler = Scheduler(with: self, callbackQueue: .main)
    private var saveInterval: TimeInterval
    private var pendingName: String?
    private var pendingWalletId: String?

    private var accountReplaceCancellableStore = CancellableCallStore()

    init(
        cloudBackupSyncFacade: CloudBackupSyncFacadeProtocol,
        walletCreationRequestFactory: WalletCreationRequestFactoryProtocol,
        walletRepository: AnyDataProviderRepository<ManagedMetaAccountModel>,
        accountOperationFactory: MetaAccountOperationFactoryProtocol,
        chainRepository: AnyDataProviderRepository<ChainModel>,
        operationQueue: OperationQueue,
        settings: SelectedWalletSettings,
        eventCenter: EventCenterProtocol,
        keystore: KeystoreProtocol,
        chainsFilter: AccountManagementFilterProtocol,
        saveInterval: TimeInterval = 2.0
    ) {
        self.cloudBackupSyncFacade = cloudBackupSyncFacade
        self.walletCreationRequestFactory = walletCreationRequestFactory
        self.walletRepository = walletRepository
        self.accountOperationFactory = accountOperationFactory
        self.chainRepository = chainRepository
        self.operationQueue = operationQueue
        self.settings = settings
        self.eventCenter = eventCenter
        self.keystore = keystore
        self.chainsFilter = chainsFilter
        self.saveInterval = saveInterval
    }

    // MARK: - Fetching functions

    private func filterChainsAndNotify(for chains: [ChainModel], wallet: MetaAccountModel) {
        let filteredChains = chains.filter { chainsFilter.accountManagementSupports(wallet: wallet, for: $0) }
        presenter?.didReceiveChains(.success(filteredChains.reduceToDict()))
    }

    private func fetchChains(for wallet: MetaAccountModel) {
        let operation = chainRepository.fetchAllOperation(with: RepositoryFetchOptions())

        execute(
            operation: operation,
            inOperationQueue: operationQueue,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(chains):
                self?.filterChainsAndNotify(for: chains, wallet: wallet)
            case let .failure(error):
                self?.presenter?.didReceiveChains(.failure(error))
            }
        }
    }

    private func fetchWalletAndChains(with walletId: String) {
        let operation = walletRepository.fetchOperation(
            by: walletId,
            options: RepositoryFetchOptions()
        )

        execute(
            operation: operation,
            inOperationQueue: operationQueue,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(optManagedWallet):
                let optWallet = optManagedWallet?.info

                if let wallet = optWallet {
                    self?.fetchChains(for: wallet)
                    self?.fetchProxyWalletIfNeeded(for: wallet)
                } else {
                    self?.presenter?.didReceiveChains(.success([:]))
                }

                self?.presenter?.didReceiveWallet(.success(optWallet))
            case let .failure(error):
                self?.presenter?.didReceiveWallet(.failure(error))
                self?.presenter?.didReceiveChains(.failure(error))
            }
        }
    }

    private func fetchProxyWalletIfNeeded(for wallet: MetaAccountModel) {
        guard wallet.type == .proxied,
              let chainAccount = wallet.chainAccounts.first(where: { $0.proxy != nil }),
              let proxy = chainAccount.proxy else {
            return
        }

        let operation = walletRepository.fetchAllOperation(with: RepositoryFetchOptions())

        execute(
            operation: operation,
            inOperationQueue: operationQueue,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(wallets):
                let proxyWallet = wallets.first(where: { $0.info.has(
                    accountId: proxy.accountId,
                    chainId: chainAccount.chainId
                ) })?.info
                self?.presenter?.didReceiveProxyWallet(.success(proxyWallet))
            case let .failure(error):
                self?.presenter?.didReceiveProxyWallet(.failure(error))
            }
        }
    }

    // MARK: - Result handling functions

    private func handleNameSaveOperationResult(
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
            } else {
                eventCenter.notify(with: WalletNameChanged())
            }

            presenter?.didSaveWalletName(.success(newName))

        case let .failure(error):
            presenter?.didSaveWalletName(.failure(error))
        }
    }

    private func handleAccountCreation(for walletId: MetaAccountModel.Id, chain: ChainModel) {
        if let selectedWallet = settings.value, selectedWallet.identifier == walletId {
            settings.setup()

            eventCenter.notify(with: SelectedAccountChanged())
        }

        eventCenter.notify(with: ChainAccountChanged(method: .manually))

        fetchWalletAndChains(with: walletId)

        presenter?.didReceiveAccountCreationResult(.success(()), chain: chain)
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
                throw AccountManagementError.missingAccount
            }

            guard currentItem.info.name != newName else {
                return []
            }

            let newInfo = currentItem.info.replacingName(with: newName)
            let changedItem = currentItem.replacingInfo(newInfo)

            return [changedItem]
        }, { [] })

        saveOperation.addDependency(fetchOperation)

        let wrapper = CompoundOperationWrapper(targetOperation: saveOperation, dependencies: [fetchOperation])

        execute(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            runningCallbackIn: .main
        ) { [weak self] _ in
            self?.handleNameSaveOperationResult(
                result: saveOperation.result,
                newName: newName,
                walletId: walletId
            )
        }
    }

    private func performChangeFinalizationIfNeeded() {
        guard let name = pendingName, let walletId = pendingWalletId else { return }

        pendingName = nil
        pendingWalletId = nil

        performWalletNameSave(newName: name, for: walletId)
    }

    private func subscribeCloudBackupState() {
        cloudBackupSyncFacade.subscribeState(
            self,
            notifyingIn: .main
        ) { [weak self] state in
            self?.presenter?.didReceiveCloudBackup(state: state)
        }
    }
}

// MARK: - AccountManagementInteractorInputProtocol

extension AccountManagementInteractor: AccountManagementInteractorInputProtocol {
    func setup(walletId: String) {
        subscribeCloudBackupState()
        fetchWalletAndChains(with: walletId)
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

            var options: [SecretSource] = []

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

            options.append(.keystore)

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

    func createAccount(for walletId: MetaAccountModel.Id, chain: ChainModel) {
        guard !accountReplaceCancellableStore.hasCall else {
            return
        }

        do {
            let request = try walletCreationRequestFactory.createAccountRequest(for: chain)

            let walletFetchOperation = walletRepository.fetchOperation(by: walletId, options: RepositoryFetchOptions())

            let accountReplaceWrapper: CompoundOperationWrapper<MetaAccountModel>
            accountReplaceWrapper = OperationCombiningService.compoundNonOptionalWrapper(
                operationManager: OperationManager(operationQueue: operationQueue)
            ) {
                guard let wallet = try walletFetchOperation.extractNoCancellableResultData()?.info else {
                    throw AccountManagementError.missingAccount
                }

                let accountCreationOperation = self.accountOperationFactory.replaceChainAccountOperation(
                    for: wallet,
                    request: request,
                    chainId: chain.chainId
                )

                return CompoundOperationWrapper(targetOperation: accountCreationOperation)
            }

            accountReplaceWrapper.addDependency(operations: [walletFetchOperation])

            let saveOperation = walletRepository.saveOperation({
                guard let originalManagedWallet = try walletFetchOperation.extractNoCancellableResultData() else {
                    return []
                }

                let changedWallet = try accountReplaceWrapper.targetOperation.extractNoCancellableResultData()

                let changedManagedWallet = originalManagedWallet.replacingInfo(changedWallet)

                return [changedManagedWallet]
            }, {
                []
            })

            saveOperation.addDependency(accountReplaceWrapper.targetOperation)

            let wrapper = accountReplaceWrapper
                .insertingHead(operations: [walletFetchOperation])
                .insertingTail(operation: saveOperation)

            executeCancellable(
                wrapper: wrapper,
                inOperationQueue: operationQueue,
                backingCallIn: accountReplaceCancellableStore,
                runningCallbackIn: .main
            ) { [weak self] result in
                switch result {
                case .success:
                    self?.handleAccountCreation(for: walletId, chain: chain)
                case let .failure(error):
                    self?.presenter?.didReceiveAccountCreationResult(.failure(error), chain: chain)
                }
            }
        } catch {
            presenter?.didReceiveAccountCreationResult(.failure(error), chain: chain)
        }
    }
}

// MARK: - SchedulerDelegate

extension AccountManagementInteractor: SchedulerDelegate {
    func didTrigger(scheduler _: SchedulerProtocol) {
        performChangeFinalizationIfNeeded()
    }
}
