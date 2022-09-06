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

    // stores derivation paths for new accounts
    private var derivationPaths: [AccountId: Data] = [:]

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
            if let wallet = wallet, let response = wallet.fetch(for: chain.accountRequest()) {
                let info = LedgerChainAccount.Info(
                    accountId: response.accountId,
                    publicKey: response.publicKey,
                    cryptoType: response.cryptoType
                )

                return LedgerChainAccount(chain: chain, info: info)
            } else {
                let info = currentChainAccounts[chain.chainId]?.info
                return LedgerChainAccount(chain: chain, info: info)
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

    func add(chain: ChainModel, info: LedgerChainAccount.Info, derivationPath: Data) {
        derivationPaths[info.accountId] = derivationPath

        let chainAccount = LedgerChainAccount(chain: chain, info: info)

        if let replacingIndex = state.firstIndex(where: { $0.chain.chainId == chainAccount.chain.chainId }) {
            state[replacingIndex] = chainAccount
        } else {
            state.append(chainAccount)
        }
    }

    func derivationPath(for accountId: AccountId) -> Data? {
        derivationPaths[accountId]
    }
}
