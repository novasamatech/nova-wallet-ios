import BigInt
import Foundation
import Operation_iOS

protocol AutoAddTokensServiceProtocol: ApplicationServiceProtocol {
    func update(selectedMetaAccount: MetaAccountModel)
}

final class AutoAddTokensService: AnyProviderAutoCleaning {
    let chainRegistry: ChainRegistryProtocol
    let walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol
    let externalBalancesSubscriptionFactory: ExternalBalanceLocalSubscriptionFactoryProtocol
    let assetVisibilitySubscriptionFactory: AssetVisibilityLocalSubscriptionFactoryProtocol
    let visibilityWriter: AssetVisibilityWriting
    let defaultAssetsProvider: DefaultAssetsProviding
    let operationQueue: OperationQueue
    let logger: LoggerProtocol

    private let mutex = NSLock()

    private var selectedMetaAccount: MetaAccountModel?
    private var balances: [String: AssetBalance] = [:]
    private var externalBalances: [String: ExternalAssetBalance] = [:]
    private var autoAddEnabled: Bool?
    private var lastCandidates: Set<ChainAssetId> = []
    private var balancesProvider: StreamableProvider<AssetBalance>?
    private var externalBalancesProvider: StreamableProvider<ExternalAssetBalance>?
    private var settingsProvider: StreamableProvider<MetaAccountSettingsLocal>?

    init(
        selectedMetaAccount: MetaAccountModel?,
        chainRegistry: ChainRegistryProtocol,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        externalBalancesSubscriptionFactory: ExternalBalanceLocalSubscriptionFactoryProtocol,
        assetVisibilitySubscriptionFactory: AssetVisibilityLocalSubscriptionFactoryProtocol,
        visibilityWriter: AssetVisibilityWriting,
        defaultAssetsProvider: DefaultAssetsProviding,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.selectedMetaAccount = selectedMetaAccount
        self.chainRegistry = chainRegistry
        self.walletLocalSubscriptionFactory = walletLocalSubscriptionFactory
        self.externalBalancesSubscriptionFactory = externalBalancesSubscriptionFactory
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
        externalBalancesProvider = subscribeToAllExternalAssetBalancesProvider()
        subscribeSettings()
        warmUpDefaultAssets()
    }

    func throttle() {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        clear(streamableProvider: &balancesProvider)
        clear(streamableProvider: &externalBalancesProvider)
        clear(streamableProvider: &settingsProvider)

        balances = [:]
        externalBalances = [:]
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

// MARK: ExternalAssetBalanceSubscriber

extension AutoAddTokensService: ExternalAssetBalanceSubscriber, ExternalAssetBalanceSubscriptionHandler {
    func handleAllExternalAssetBalances(
        result: Result<[DataProviderChange<ExternalAssetBalance>], Error>
    ) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        switch result {
        case let .success(changes):
            externalBalances = changes.mergeToDict(externalBalances)
            revealAssetsWithBalance()
        case let .failure(error):
            logger.error("Can't observe external balances: \(error)")
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
        guard let wallet = selectedMetaAccount else {
            return
        }

        let ordinaryCandidates = balances.values.compactMap { balance in
            positiveBalanceAssetId(
                balance.chainAssetId,
                amount: balance.totalInPlank,
                accountId: balance.accountId,
                wallet: wallet
            )
        }
        let externalCandidates = externalBalances.values.compactMap { balance in
            positiveBalanceAssetId(
                balance.chainAssetId,
                amount: balance.amount,
                accountId: balance.accountId,
                wallet: wallet
            )
        }
        let candidates = Set(ordinaryCandidates).union(externalCandidates)

        guard candidates != lastCandidates else {
            return
        }

        lastCandidates = candidates

        visibilityWriter.apply(
            event: .passivePositiveBalance(autoAddEnabled: autoAddEnabled == true),
            metaId: wallet.metaId,
            ids: candidates,
            runningCallbackIn: nil,
            completion: nil
        )
    }

    func positiveBalanceAssetId(
        _ chainAssetId: ChainAssetId,
        amount: BigUInt,
        accountId: AccountId,
        wallet: MetaAccountModel
    ) -> ChainAssetId? {
        guard
            amount > 0,
            let chain = chainRegistry.getChain(for: chainAssetId.chainId),
            wallet.fetch(for: chain.accountRequest())?.accountId == accountId else {
            return nil
        }

        return chainAssetId
    }
}
