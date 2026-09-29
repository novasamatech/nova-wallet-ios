import Foundation
import Operation_iOS
import Keystore_iOS

protocol BittensorLocalBannerSourceDelegate: AnyObject {
    func bittensorLocalBannerSource(didResolve banner: BittensorLocalBanner?)
}

protocol BittensorLocalBannerSourceProtocol: AnyObject {
    var delegate: BittensorLocalBannerSourceDelegate? { get set }

    func setup()
    func refresh()
}

final class BittensorLocalBannerSource {
    weak var delegate: BittensorLocalBannerSourceDelegate?

    let chainRegistry: ChainRegistryProtocol
    let selectedWalletSettings: SelectedWalletSettings
    let walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol
    let earnConfigProvider: SubtensorEarnConfigProviderProtocol
    let settingsManager: SettingsManagerProtocol
    let eventCenter: EventCenterProtocol
    let operationQueue: OperationQueue
    let logger: LoggerProtocol

    private let configCallStore = CancellableCallStore()
    private var chain: ChainModel?
    private var config: SubtensorEarnConfig?
    private var accountId: AccountId?
    private var balance: Result<AssetBalance?, Error>?
    private var balanceProvider: StreamableProvider<AssetBalance>?
    private var banner: BittensorLocalBanner?

    init(
        chainRegistry: ChainRegistryProtocol,
        selectedWalletSettings: SelectedWalletSettings,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        earnConfigProvider: SubtensorEarnConfigProviderProtocol,
        settingsManager: SettingsManagerProtocol,
        eventCenter: EventCenterProtocol,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.chainRegistry = chainRegistry
        self.selectedWalletSettings = selectedWalletSettings
        self.walletLocalSubscriptionFactory = walletLocalSubscriptionFactory
        self.earnConfigProvider = earnConfigProvider
        self.settingsManager = settingsManager
        self.eventCenter = eventCenter
        self.operationQueue = operationQueue
        self.logger = logger
    }

    deinit {
        configCallStore.cancel()
        chainRegistry.chainsUnsubscribe(self)
    }
}

private extension BittensorLocalBannerSource {
    func fetchConfig() {
        configCallStore.cancel()

        executeCancellable(
            wrapper: earnConfigProvider.createConfigWrapper(),
            inOperationQueue: operationQueue,
            backingCallIn: configCallStore,
            runningCallbackIn: .main
        ) { [weak self] result in
            guard let self else {
                return
            }

            switch result {
            case let .success(config):
                self.config = config
            case let .failure(error):
                config = nil
                logger.error("Bittensor banner config failed: \(error)")
            }

            resolve()
        }
    }

    func apply(chainChanges changes: [DataProviderChange<ChainModel>]) {
        for change in changes {
            switch change {
            case let .insert(newItem), let .update(newItem):
                chain = newItem
            case .delete:
                chain = nil
            }
        }

        updateBalanceSubscription()
        resolve()
    }

    func updateBalanceSubscription() {
        let chainAsset = chain.flatMap(BittensorLocalBanner.chainAsset(for:))
        let newAccountId = chainAsset.flatMap { chainAsset in
            selectedWalletSettings.value?.fetch(for: chainAsset.chain.accountRequest())?.accountId
        }

        guard newAccountId != accountId else {
            return
        }

        balanceProvider?.removeObserver(self)
        balanceProvider = nil
        accountId = newAccountId

        guard let newAccountId, let chainAsset else {
            balance = nil
            return
        }

        balanceProvider = subscribeToAssetBalanceProvider(
            for: newAccountId,
            chainId: chainAsset.chain.chainId,
            assetId: chainAsset.asset.assetId
        )
    }

    func resolve() {
        let connectedChain = chain.flatMap { chain in
            chainRegistry.getConnection(for: chain.chainId) != nil ? chain : nil
        }

        let newBanner = BittensorLocalBanner.resolve(
            connectedChain: connectedChain,
            config: config,
            hasAccount: accountId != nil,
            balance: balance,
            closedBanners: settingsManager.closedBanners
        )

        guard newBanner != banner else {
            return
        }

        banner = newBanner
        delegate?.bittensorLocalBannerSource(didResolve: newBanner)
    }
}

extension BittensorLocalBannerSource: BittensorLocalBannerSourceProtocol {
    func setup() {
        eventCenter.add(observer: self, dispatchIn: .main)

        chainRegistry.chainsSubscribe(
            self,
            runningInQueue: .main,
            filterStrategy: .chainId(KnowChainId.bittensor)
        ) { [weak self] changes in
            self?.apply(chainChanges: changes)
        }

        fetchConfig()
    }

    func refresh() {
        fetchConfig()
    }
}

extension BittensorLocalBannerSource: WalletLocalStorageSubscriber, WalletLocalSubscriptionHandler {
    func handleAssetBalance(
        result: Result<AssetBalance?, Error>,
        accountId: AccountId,
        chainId: ChainModel.Id,
        assetId _: AssetModel.Id
    ) {
        guard accountId == self.accountId, chainId == chain?.chainId else {
            return
        }

        balance = result
        resolve()
    }
}

extension BittensorLocalBannerSource: EventVisitorProtocol {
    func processSelectedWalletChanged(event _: SelectedWalletSwitched) {
        updateBalanceSubscription()
        resolve()
    }

    func processChainAccountChanged(event _: ChainAccountChanged) {
        updateBalanceSubscription()
        resolve()
    }
}
