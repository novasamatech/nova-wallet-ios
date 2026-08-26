import Foundation_iOS
import Operation_iOS
import SubstrateSdk
import UIKit

final class SubtensorStakingDetailsInteractor: AnyProviderAutoCleaning {
    weak var presenter: SubtensorStakingDetailsInteractorOutputProtocol?

    let selectedAccount: MetaChainAccountResponse
    let sharedState: SubtensorStakingSharedStateProtocol
    let walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    let stakingRewardsLocalSubscriptionFactory: StakingRewardsLocalSubscriptionFactoryProtocol
    let networkInfoFactory: SubtensorNetworkInfoFactoryProtocol
    let applicationHandler: ApplicationHandlerProtocol
    let operationQueue: OperationQueue
    let logger: LoggerProtocol

    var priceProvider: StreamableProvider<PriceData>?
    var balanceProvider: StreamableProvider<AssetBalance>?
    var totalRewardProvider: AnySingleValueProvider<TotalRewardItem>?

    var totalRewardInterval: StakingRewardFiltersInterval?

    let networkInfoReqStore = CancellableCallStore()

    var chain: ChainModel {
        chainAsset.chain
    }

    var chainAsset: ChainAsset {
        sharedState.stakingOption.chainAsset
    }

    var selectedAccountId: AccountId {
        selectedAccount.chainAccount.accountId
    }

    init(
        selectedAccount: MetaChainAccountResponse,
        sharedState: SubtensorStakingSharedStateProtocol,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        stakingRewardsLocalSubscriptionFactory: StakingRewardsLocalSubscriptionFactoryProtocol,
        networkInfoFactory: SubtensorNetworkInfoFactoryProtocol,
        applicationHandler: ApplicationHandlerProtocol,
        currencyManager: CurrencyManagerProtocol,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.selectedAccount = selectedAccount
        self.sharedState = sharedState
        self.walletLocalSubscriptionFactory = walletLocalSubscriptionFactory
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.stakingRewardsLocalSubscriptionFactory = stakingRewardsLocalSubscriptionFactory
        self.networkInfoFactory = networkInfoFactory
        self.applicationHandler = applicationHandler
        self.operationQueue = operationQueue
        self.logger = logger
        self.currencyManager = currencyManager
    }

    deinit {
        networkInfoReqStore.cancel()
        sharedState.throttle()
    }
}

private extension SubtensorStakingDetailsInteractor {
    func setupState() {
        sharedState.setup(for: selectedAccountId)

        presenter?.didReceiveChainAsset(chainAsset)
        presenter?.didReceiveAccount(selectedAccount)
    }

    func makeBalanceSubscription() {
        clear(streamableProvider: &balanceProvider)

        balanceProvider = subscribeToAssetBalanceProvider(
            for: selectedAccountId,
            chainId: chain.chainId,
            assetId: chainAsset.asset.assetId
        )
    }

    func makePriceSubscription() {
        clear(streamableProvider: &priceProvider)

        guard let priceId = chainAsset.asset.priceId else {
            return
        }

        priceProvider = subscribeToPrice(for: priceId, currency: selectedCurrency)
    }

    func makePositionsSubscription() {
        sharedState.positionsSyncService?.add(
            observer: self,
            sendStateOnSubscription: true,
            queue: .main
        ) { [weak self] _, newState in
            self?.presenter?.didReceivePositionsState(newState)
        }

        sharedState.positionsSyncService?.add(
            failureObserver: self,
            sendStateOnSubscription: false,
            queue: .main
        ) { [weak self] _, isFailed in
            self?.presenter?.didReceiveSyncFailure(isFailed)
        }
    }

    func makeClaimableSubscription() {
        sharedState.rootClaimableService?.add(
            observer: self,
            sendStateOnSubscription: true,
            queue: .main
        ) { [weak self] _, newState in
            self?.presenter?.didReceiveClaimable(newState)
        }
    }

    func provideDelegates() {
        sharedState.delegatesService.fetchDelegates(
            runningCompletionIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(delegates):
                self?.presenter?.didReceiveDelegates(delegates)
            case let .failure(error):
                self?.logger.error("Delegates fetch failed: \(error)")
            }
        }
    }

    func provideSubnetsInfo() {
        sharedState.subnetsService.fetchSubnetsInfo(
            runningCompletionIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(subnetsInfo):
                self?.presenter?.didReceiveSubnetsInfo(subnetsInfo)
            case let .failure(error):
                self?.logger.error("Subnets info fetch failed: \(error)")
            }
        }
    }

    func provideNetworkInfo() {
        networkInfoReqStore.cancel()

        let wrapper = networkInfoFactory.createNetworkInfoWrapper()

        executeCancellable(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            backingCallIn: networkInfoReqStore,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(networkInfo):
                self?.presenter?.didReceiveNetworkInfo(networkInfo)
            case let .failure(error):
                self?.logger.error("Network info request failed: \(error)")
            }
        }
    }

    func makeTotalRewardSubscription() {
        clear(singleValueProvider: &totalRewardProvider)

        if
            let address = selectedAccount.chainAccount.toChecksumedAddress(),
            let rewardApi = chain.externalApis?.stakingRewards() {
            totalRewardProvider = subscribeTotalReward(
                for: address,
                startTimestamp: totalRewardInterval?.startTimestamp,
                endTimestamp: totalRewardInterval?.endTimestamp,
                api: rewardApi,
                assetPrecision: Int16(chainAsset.asset.precision)
            )
        } else {
            presenter?.didReceiveTotalReward(nil)
        }
    }
}

extension SubtensorStakingDetailsInteractor: SubtensorStakingDetailsInteractorInputProtocol {
    func setup() {
        setupState()

        makeBalanceSubscription()
        makePriceSubscription()
        makePositionsSubscription()
        makeClaimableSubscription()
        makeTotalRewardSubscription()

        provideDelegates()
        provideSubnetsInfo()
        provideNetworkInfo()

        applicationHandler.delegate = self
    }

    func update(totalRewardFilter: StakingRewardFiltersPeriod) {
        totalRewardInterval = totalRewardFilter.interval
        makeTotalRewardSubscription()
    }

    func retryPositionsSync() {
        sharedState.positionsSyncService?.refresh()
    }
}

extension SubtensorStakingDetailsInteractor: WalletLocalStorageSubscriber,
    WalletLocalSubscriptionHandler {
    func handleAssetBalance(
        result: Result<AssetBalance?, Error>,
        accountId: AccountId,
        chainId: ChainModel.Id,
        assetId: AssetModel.Id
    ) {
        guard
            chainId == chain.chainId,
            assetId == chainAsset.asset.assetId,
            accountId == selectedAccountId else {
            return
        }

        switch result {
        case let .success(balance):
            presenter?.didReceiveAssetBalance(balance)
        case let .failure(error):
            logger.error("Balance subscription error: \(error)")
        }
    }
}

extension SubtensorStakingDetailsInteractor: StakingRewardsLocalSubscriber, StakingRewardsLocalHandler {
    func handleTotalReward(
        result: Result<TotalRewardItem, Error>,
        for _: AccountAddress,
        api _: Set<LocalChainExternalApi>
    ) {
        switch result {
        case let .success(rewardItem):
            presenter?.didReceiveTotalReward(rewardItem)
        case let .failure(error):
            logger.error("Total rewards subscription: \(error)")
        }
    }
}

extension SubtensorStakingDetailsInteractor: ApplicationHandlerDelegate {
    func didReceiveDidBecomeActive(notification _: Notification) {
        priceProvider?.refresh()
        totalRewardProvider?.refresh()
        sharedState.positionsSyncService?.refresh()

        // safe mode is chain-wide and can clear while the app is backgrounded, so the banner
        // must have a chance to disappear on its own
        provideNetworkInfo()
    }
}

extension SubtensorStakingDetailsInteractor: PriceLocalStorageSubscriber, PriceLocalSubscriptionHandler {
    func handlePrice(result: Result<PriceData?, Error>, priceId: AssetModel.PriceId) {
        if chainAsset.asset.priceId == priceId {
            switch result {
            case let .success(priceData):
                presenter?.didReceivePrice(priceData)
            case let .failure(error):
                logger.error("Price subscription error: \(error)")
            }
        }
    }
}

extension SubtensorStakingDetailsInteractor: SelectedCurrencyDepending {
    func applyCurrency() {
        guard presenter != nil else {
            return
        }

        makePriceSubscription()
    }
}
