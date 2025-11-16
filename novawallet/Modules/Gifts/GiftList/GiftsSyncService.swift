import Foundation
import Operation_iOS

protocol GiftsSyncServiceProtocol {
    func add(
        observer: AnyObject,
        sendStateOnSubscription: Bool,
        queue: DispatchQueue?,
        closure: @escaping Observable<[GiftModel.Id: GiftModel]?>.StateChangeClosure
    )
    func remove(observer: AnyObject)
    func reset()
}

final class GiftsSyncService: BaseObservableStateStore<[GiftModel.Id: GiftModel]>, AnyProviderAutoCleaning {
    let chainRegistry: ChainRegistryProtocol
    let giftsLocalSubscriptionFactory: GiftsLocalSubscriptionFactoryProtocol
    let walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol
    let balanceRemoteSubscriptionFactory: WalletRemoteSubscriptionWrapperProtocol
    let assetStorageOperationFactory: AssetStorageInfoOperationFactoryProtocol
    let selectedMetaId: MetaAccountModel.Id
    let operationQueue: OperationQueue
    let workingQueue: DispatchQueue
    
    var giftsLocalSubscription: StreamableProvider<GiftModel>?
    var localBalancesLocalSubscriptions: [AccountId: StreamableProvider<AssetBalance>] = [:]
    var remoteBalancesSubscriptions: [AccountId: UUID] = [:]
    var assetStorageInfo: [ChainAssetId: AssetStorageInfo] = [:]
    var balanceExistence: [ChainAssetId: AssetBalanceExistence] = [:]
    
    var gifts: [GiftModel.Id: GiftModel] = [:]
    var syncingGifts: Set<AccountId> = []
    
    init(
        chainRegistry: ChainRegistryProtocol,
        giftsLocalSubscriptionFactory: GiftsLocalSubscriptionFactoryProtocol,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        balanceRemoteSubscriptionFactory: WalletRemoteSubscriptionWrapperProtocol,
        assetStorageOperationFactory: AssetStorageInfoOperationFactoryProtocol,
        selectedMetaId: MetaAccountModel.Id,
        operationQueue: OperationQueue,
        workingQueue: DispatchQueue,
        logger: LoggerProtocol
    ) {
        self.chainRegistry = chainRegistry
        self.giftsLocalSubscriptionFactory = giftsLocalSubscriptionFactory
        self.walletLocalSubscriptionFactory = walletLocalSubscriptionFactory
        self.balanceRemoteSubscriptionFactory = balanceRemoteSubscriptionFactory
        self.assetStorageOperationFactory = assetStorageOperationFactory
        self.selectedMetaId = selectedMetaId
        self.operationQueue = operationQueue
        self.workingQueue = workingQueue
        
        super.init(logger: logger)
        
        setup()
    }
}

// MARK: - Private

private extension GiftsSyncService {
    func setup() {
        giftsLocalSubscription = subscribeAllGifts(for: selectedMetaId)
    }
    
    func updateSubscriptions(for changes: [DataProviderChange<GiftModel>]) {
        changes
            .compactMap { $0.item }
            .filter { $0.status == .pending }
            .forEach { subscribeBalance(for: $0) }
        
        changes
            .compactMap { $0.item }
            .filter { $0.status == .claimed || $0.status == .reclaimed }
            .forEach { unsubscribeBalance(for: $0) }
    }
    
    func subscribeBalance(for gift: GiftModel) {
        guard
            let chain = chainRegistry.getChain(for: gift.chainAssetId.chainId),
            let chainAsset = chain.chainAsset(for: gift.chainAssetId.assetId),
            let runtimeProvider = chainRegistry.getRuntimeProvider(for: chain.chainId)
        else {
            return
        }
        
        let assetStorageWrapper = assetStorageOperationFactory.createStorageInfoWrapper(
            from: chainAsset.asset,
            runtimeProvider: runtimeProvider
        )
        let balanceExistenceWrapper = assetStorageOperationFactory.createAssetBalanceExistenceOperation(
            chainId: chain.chainId,
            asset: chainAsset.asset,
            runtimeProvider: runtimeProvider,
            operationQueue: operationQueue
        )
        let resultOperation = ClosureOperation {
            let assetStorageInfo = try assetStorageWrapper.targetOperation.extractNoCancellableResultData()
            let balanceExistence = try balanceExistenceWrapper.targetOperation.extractNoCancellableResultData()
            
            return (assetStorageInfo, balanceExistence)
        }
        
        resultOperation.addDependency(assetStorageWrapper.targetOperation)
        resultOperation.addDependency(balanceExistenceWrapper.targetOperation)
        
        execute(
            operation: resultOperation,
            inOperationQueue: operationQueue,
            runningCallbackIn: workingQueue
        ) { [weak self] result in
            switch result {
            case let .success((assetInfo, balanceExistence)):
                self?.mutex.lock()
                defer { self?.mutex.unlock() }
                
                self?.assetStorageInfo[chainAsset.chainAssetId] = assetInfo
                self?.balanceExistence[chainAsset.chainAssetId] = balanceExistence
                
                self?.remoteBalancesSubscriptions[gift.giftAccountId] = self?.balanceRemoteSubscriptionFactory.subscribe(
                    using: assetInfo,
                    accountId: gift.giftAccountId,
                    chainAsset: chainAsset,
                    completion: nil
                )
                self?.localBalancesLocalSubscriptions[gift.giftAccountId] = self?.subscribeToAssetBalanceProvider(
                    for: gift.giftAccountId,
                    chainId: gift.chainAssetId.chainId,
                    assetId: gift.chainAssetId.assetId
                )
            case let .failure(error):
                self?.logger.error("Failed on fetch asset storage info: \(error)")
            }
        }
    }
    
    func updateStatus(
        for giftAccountId: AccountId,
        chainAssetId: ChainAssetId,
        balance: AssetBalance
    ) {
        guard
            let gift = stateObservable.state?[giftAccountId.toHex()],
            let balanceExistence = balanceExistence[chainAssetId]
        else { return }
        
        let status: GiftModel.Status = balance.transferable > balanceExistence.minBalance
            ? .pending
            : .claimed
        
        guard gift.status != status else { return }
        
        stateObservable.state?[giftAccountId.toHex()] = gift.updating(status: status)
        
        guard status == .claimed else { return }
    }
    
    func unsubscribeBalance(for gift: GiftModel) {
        guard
            let chain = chainRegistry.getChain(for: gift.chainAssetId.chainId),
            let chainAsset = chain.chainAsset(for: gift.chainAssetId.assetId),
            let assetStorageInfo = assetStorageInfo[chainAsset.chainAssetId],
            let subscriptionId = remoteBalancesSubscriptions[gift.giftAccountId]
        else { return }
        
        balanceRemoteSubscriptionFactory.unsubscribe(
            from: subscriptionId,
            assetStorageInfo: assetStorageInfo,
            accountId: gift.giftAccountId,
            chainAssetId: chainAsset.chainAssetId,
            completion: nil
        )
        remoteBalancesSubscriptions[gift.giftAccountId] = nil
        clear(streamableProvider: &localBalancesLocalSubscriptions[gift.giftAccountId])
    }
}

// MARK: - GiftsLocalStorageSubscriber

extension GiftsSyncService: GiftsLocalStorageSubscriber, GiftsLocalSubscriptionHandler {
    func handleAllGifts(result: Result<[DataProviderChange<GiftModel>], any Error>) {
        mutex.lock()
        defer { mutex.unlock() }
        
        switch result {
        case let .success(changes):
            stateObservable.state = changes.mergeToDict(stateObservable.state ?? [:])
            updateSubscriptions(for: changes)
        case let .failure(error):
            logger.error("Failed on gifts subscription: \(error)")
        }
    }
}

// MARK: - WalletLocalStorageSubscriber

extension GiftsSyncService: WalletLocalStorageSubscriber, WalletLocalSubscriptionHandler {
    func handleAssetBalance(
        result: Result<AssetBalance?, any Error>,
        accountId: AccountId,
        chainId: ChainModel.Id,
        assetId: AssetModel.Id
    ) {
        mutex.lock()
        defer { mutex.unlock() }
        
        switch result {
        case let .success(balance):
            guard let balance else { return }
            
            updateStatus(
                for: accountId,
                chainAssetId: ChainAssetId(chainId: chainId, assetId: assetId),
                balance: balance
            )
        case let .failure(error):
            logger.error("Failed local balance subscription: \(error)")
        }
    }
}

// MARK: - GiftsSyncServiceProtocol

extension GiftsSyncService: GiftsSyncServiceProtocol {}
