import Foundation
import RobinHood

final class LedgerAccountsStore: Observable<[LedgerChainAccount]> {
    let walletId: String?
    let chainRegistry: ChainRegistryProtocol
    let supportedApps: [SupportedLedgerApp]
    let repository: AnyDataProviderRepository<MetaAccountModel>
    let operationQueue: OperationQueue
    let logger: LoggerProtocol

    private var currentChains: [ChainModel.Id: ChainModel]?
    private var wallet: MetaAccountModel?
    private var walletProvider: StreamableProvider<ManagedMetaAccountModel>?

    init(
        chainRegistry: ChainRegistryProtocol,
        supportedApps: [SupportedLedgerApp],
        walletId: String?,
        repository: AnyDataProviderRepository<MetaAccountModel>,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.chainRegistry = chainRegistry
        self.supportedApps = supportedApps
        self.walletId = walletId
        self.repository = repository
        self.operationQueue = operationQueue
        self.logger = logger

        super.init(state: [])
    }

    private func subscribeChainRegistry() {
        chainRegistry.chainsSubscribe(self, runningInQueue: .main) { [weak self] changes in
            self?.currentChains = changes.mergeToDict(self?.currentChains ?? [:])
            self?.updateChainAccounts()
        }
    }

    private func fetchWallet(by walletId: String) {
        let operation = repository.fetchOperation(by: walletId, options: RepositoryFetchOptions())

        operation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                do {
                    self?.wallet = try operation.extractNoCancellableResultData()
                    self?.updateChainAccounts()
                } catch {
                    self?.logger.error("Unexpected error: \(error)")
                }
            }
        }

        operationQueue.addOperation(operation)
    }

    private func updateChainAccounts() {
        guard let currentChains = currentChains else {
            return
        }

        let supportedChains = supportedApps.compactMap { application in
            currentChains[application.chainId]
        }

        let currentChainAccounts = state.reduce(into: [ChainModel.Id: LedgerChainAccount]()) { result, chainAccount in
            result[chainAccount.chain.chainId] = chainAccount
        }

        let chainAccounts: [LedgerChainAccount] = supportedChains.map { chain in
            if let wallet = wallet, let accountId = wallet.fetchChainAccountId(for: chain.accountRequest()) {
                return LedgerChainAccount(chain: chain, accountId: accountId)
            } else {
                let accountId = currentChainAccounts[chain.chainId]?.accountId
                return LedgerChainAccount(chain: chain, accountId: accountId)
            }
        }

        state = chainAccounts
    }

    func setup() {
        subscribeChainRegistry()

        if let walletId = walletId {
            fetchWallet(by: walletId)
        }
    }
}
