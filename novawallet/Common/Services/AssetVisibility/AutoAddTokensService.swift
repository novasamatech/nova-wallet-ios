import Foundation
import Operation_iOS

protocol AutoAddTokensServiceProtocol: ApplicationServiceProtocol {
    func update(selectedMetaAccount: MetaAccountModel)
}

final class AutoAddTokensService: AnyProviderAutoCleaning {
    let chainRegistry: ChainRegistryProtocol
    let walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol
    let assetVisibilitySubscriptionFactory: AssetVisibilityLocalSubscriptionFactoryProtocol
    let visibilityWriter: AssetVisibilityWriting
    let defaultAssetsProvider: DefaultAssetsProviding
    let operationQueue: OperationQueue
    let logger: LoggerProtocol

    private let mutex = NSLock()

    private var selectedMetaAccount: MetaAccountModel?
    private var balances: [String: AssetBalance] = [:]
    private var autoAddEnabled: Bool?
    private var lastCandidates: Set<ChainAssetId> = []
    private var balancesProvider: StreamableProvider<AssetBalance>?
    private var settingsProvider: StreamableProvider<MetaAccountSettingsLocal>?

    init(
        selectedMetaAccount: MetaAccountModel?,
        chainRegistry: ChainRegistryProtocol,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        assetVisibilitySubscriptionFactory: AssetVisibilityLocalSubscriptionFactoryProtocol,
        visibilityWriter: AssetVisibilityWriting,
        defaultAssetsProvider: DefaultAssetsProviding,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.selectedMetaAccount = selectedMetaAccount
        self.chainRegistry = chainRegistry
        self.walletLocalSubscriptionFactory = walletLocalSubscriptionFactory
        self.assetVisibilitySubscriptionFactory = assetVisibilitySubscriptionFactory
        self.visibilityWriter = visibilityWriter
        self.defaultAssetsProvider = defaultAssetsProvider
        self.operationQueue = operationQueue
        self.logger = logger
    }
}

// MARK: AutoAddTokensServiceProtocol

extension AutoAddTokensService: AutoAddTokensServiceProtocol {
    func setup() {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        balancesProvider = subscribeAllBalancesProvider()
        subscribeSettings()
        warmUpDefaultAssets()
    }

    func throttle() {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        clear(streamableProvider: &balancesProvider)
        clear(streamableProvider: &settingsProvider)

        balances = [:]
        resetDiscovery()
    }

    func update(selectedMetaAccount: MetaAccountModel) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        self.selectedMetaAccount = selectedMetaAccount

        resetDiscovery()
        subscribeSettings()
    }
}

// MARK: WalletLocalStorageSubscriber

extension AutoAddTokensService: WalletLocalStorageSubscriber, WalletLocalSubscriptionHandler {
    func handleAllBalances(result: Result<[DataProviderChange<AssetBalance>], Error>) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        switch result {
        case let .success(changes):
            balances = changes.mergeToDict(balances)
            revealAssetsWithBalance()
        case let .failure(error):
            logger.error("Can't observe balances: \(error)")
        }
    }
}

// MARK: AssetVisibilityLocalStorageSubscriber

extension AutoAddTokensService: AssetVisibilityLocalStorageSubscriber, AssetVisibilitySubscriptionHandler {
    func handleMetaAccountSettings(
        result: Result<[DataProviderChange<MetaAccountSettingsLocal>], Error>,
        metaId: MetaAccountModel.Id
    ) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        guard metaId == selectedMetaAccount?.metaId else {
            return
        }

        switch result {
        case let .success(changes):
            let wasEnabled = autoAddEnabled

            // an empty snapshot or a deleted row is no decision, which reads as the default
            autoAddEnabled = changes.reduceToLastChange()?.autoAddTokensWithBalance
                ?? MetaAccountSettingsLocal.defaultAutoAddTokensWithBalance

            if autoAddEnabled == true, wasEnabled != true {
                lastCandidates = []
                revealAssetsWithBalance()
            }
        case let .failure(error):
            logger.error("Can't observe the auto add setting: \(error)")
        }
    }
}

// MARK: Private

private extension AutoAddTokensService {
    func subscribeSettings() {
        clear(streamableProvider: &settingsProvider)

        guard let metaId = selectedMetaAccount?.metaId else {
            return
        }

        settingsProvider = subscribeToMetaAccountSettingsProvider(for: metaId)
    }

    func warmUpDefaultAssets() {
        // the list never enters the auto-add decision; the fetch only memoises it for the screens that read it
        let wrapper = defaultAssetsProvider.createDefaultAssetsWrapper()

        execute(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            runningCallbackIn: nil
        ) { _ in }
    }

    func resetDiscovery() {
        autoAddEnabled = nil
        lastCandidates = []
    }

    func revealAssetsWithBalance() {
        guard let wallet = selectedMetaAccount, autoAddEnabled == true else {
            return
        }

        let candidates = Set(balances.values.compactMap { balance -> ChainAssetId? in
            guard
                balance.totalInPlank > 0,
                let chain = chainRegistry.getChain(for: balance.chainAssetId.chainId),
                wallet.fetch(for: chain.accountRequest())?.accountId == balance.accountId else {
                return nil
            }

            return balance.chainAssetId
        })

        guard candidates != lastCandidates else {
            return
        }

        lastCandidates = candidates

        visibilityWriter.showIfUndecided(metaId: wallet.metaId, ids: candidates)
    }
}
