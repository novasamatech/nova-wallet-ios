import UIKit
import RobinHood
import BigInt

class NominationPoolBondMoreBaseInteractor: AnyProviderAutoCleaning, AnyCancellableCleaning, NominationPoolsDataProviding {
    weak var basePresenter: NominationPoolBondMoreBaseInteractorOutputProtocol?
    let chainAsset: ChainAsset
    let selectedAccount: MetaChainAccountResponse
    let feeProxy: ExtrinsicFeeProxyProtocol
    let walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    let callFactory: SubstrateCallFactoryProtocol
    let extrinsicService: ExtrinsicServiceProtocol
    let npoolsOperationFactory: NominationPoolsOperationFactoryProtocol
    let runtimeService: RuntimeCodingServiceProtocol
    let npoolsLocalSubscriptionFactory: NPoolsLocalSubscriptionFactoryProtocol
    let stakingLocalSubscriptionFactory: StakingLocalSubscriptionFactoryProtocol
    let assetStorageInfoFactory: AssetStorageInfoOperationFactoryProtocol

    private var operationQueue: OperationQueue
    private lazy var operationManager = OperationManager(operationQueue: operationQueue)

    private var priceProvider: StreamableProvider<PriceData>?
    private var balanceProvider: StreamableProvider<AssetBalance>?
    private var poolMemberProvider: AnyDataProvider<DecodedPoolMember>?
    private var bondedPoolProvider: AnyDataProvider<DecodedBondedPool>?
    private var poolLedgerProvider: AnyDataProvider<DecodedLedgerInfo>?
    private var claimableRewardProvider: AnySingleValueProvider<String>?
    private var rewardPoolProvider: AnyDataProvider<DecodedRewardPool>?

    private var bondedAccountIdCancellable: CancellableCall?
    private var assetExistenceCancellable: CancellableCall?

    private var accountId: AccountId { selectedAccount.chainAccount.accountId }
    private var currentPoolId: NominationPools.PoolId?
    private var currentPoolRewardCounter: BigUInt?
    private var currentMemberRewardCounter: BigUInt?
    private var poolAccountId: AccountId?

    var chainId: ChainModel.Id { chainAsset.chain.chainId }

    init(
        chainAsset: ChainAsset,
        selectedAccount: MetaChainAccountResponse,
        runtimeService: RuntimeCodingServiceProtocol,
        feeProxy: ExtrinsicFeeProxyProtocol,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        callFactory: SubstrateCallFactoryProtocol,
        extrinsicServiceFactory: ExtrinsicServiceFactoryProtocol,
        npoolsOperationFactory: NominationPoolsOperationFactoryProtocol,
        npoolsLocalSubscriptionFactory: NPoolsLocalSubscriptionFactoryProtocol,
        stakingLocalSubscriptionFactory: StakingLocalSubscriptionFactoryProtocol,
        assetStorageInfoFactory: AssetStorageInfoOperationFactoryProtocol,
        operationQueue: OperationQueue,
        currencyManager: CurrencyManagerProtocol
    ) {
        self.chainAsset = chainAsset
        self.selectedAccount = selectedAccount
        self.feeProxy = feeProxy
        self.walletLocalSubscriptionFactory = walletLocalSubscriptionFactory
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.operationQueue = operationQueue
        self.callFactory = callFactory
        self.npoolsOperationFactory = npoolsOperationFactory
        self.runtimeService = runtimeService
        self.npoolsLocalSubscriptionFactory = npoolsLocalSubscriptionFactory
        self.stakingLocalSubscriptionFactory = stakingLocalSubscriptionFactory
        self.assetStorageInfoFactory = assetStorageInfoFactory

        extrinsicService = extrinsicServiceFactory.createService(
            account: selectedAccount.chainAccount,
            chain: chainAsset.chain
        )

        self.currencyManager = currencyManager
    }

    func subscribeAccountBalance() {
        clear(streamableProvider: &balanceProvider)

        balanceProvider = subscribeToAssetBalanceProvider(
            for: selectedAccount.chainAccount.accountId,
            chainId: chainAsset.chain.chainId,
            assetId: chainAsset.asset.assetId
        )
    }

    func subscribePrice() {
        clear(streamableProvider: &priceProvider)

        if let priceId = chainAsset.asset.priceId {
            priceProvider = subscribeToPrice(for: priceId, currency: selectedCurrency)
        } else {
            basePresenter?.didReceive(price: nil)
        }
    }

    func provideBondedAccountId() {
        clear(cancellable: &bondedAccountIdCancellable)

        guard let poolId = currentPoolId else {
            return
        }

        bondedAccountIdCancellable = fetchBondedAccounts(
            for: npoolsOperationFactory,
            poolIds: { [poolId] },
            runtimeService: runtimeService,
            operationQueue: operationQueue,
            completion: { [weak self] result in
                self?.bondedAccountIdCancellable = nil

                switch result {
                case let .success(accountIds):
                    if let accountId = accountIds[poolId] {
                        self?.poolAccountId = accountId
                        self?.subscribeBondedAccountProviders()
                    }
                case let .failure(error):
                    self?.basePresenter?.didReceive(error: .subscription(error, "bondedAccountId"))
                }
            }
        )
    }

    func subscribeBondedAccountProviders() {
        poolLedgerProvider = nil

        guard let accountId = poolAccountId else {
            return
        }

        poolLedgerProvider = subscribeLedgerInfo(for: accountId, chainId: chainId)
    }

    func createExtrinsicClosure(for points: BigUInt) -> ExtrinsicBuilderClosure {
        { builder in
            let call = NominationPools.BondExtraCall(extra: .freeBalance(points))
            return try builder.adding(call: call.runtimeCall())
        }
    }

    func subscribePoolProviders() {
        guard let poolId = currentPoolId else {
            return
        }

        bondedPoolProvider = subscribeBondedPool(for: poolId, chainId: chainId)
        rewardPoolProvider = subscribeRewardPool(for: poolId, chainId: chainId)

        subscribeClaimableRewardsProvider()
    }

    func subscribeClaimableRewardsProvider() {
        guard let poolId = currentPoolId else {
            return
        }

        claimableRewardProvider = subscribeClaimableRewards(
            for: chainId,
            poolId: poolId,
            accountId: accountId
        )

        if claimableRewardProvider == nil {
            basePresenter?.didReceive(error: .claimableRewards(CommonError.dataCorruption))
        }
    }

    func subscribePoolMember() {
        clear(dataProvider: &poolMemberProvider)
        poolMemberProvider = subscribePoolMember(for: accountId, chainId: chainId)
    }

    func provideAssetExistence() {
        let assetInfoWrapper = assetStorageInfoFactory.createStorageInfoWrapper(
            from: chainAsset.asset,
            runtimeProvider: runtimeService
        )

        let assetBalanceExistenceWrapper: CompoundOperationWrapper<AssetBalanceExistence?> =
            OperationCombiningService.compoundWrapper(operationManager: operationManager) { [weak self] in
                guard let self = self else {
                    return nil
                }
                let assetInfo = try assetInfoWrapper.targetOperation.extractNoCancellableResultData()

                return self.assetStorageInfoFactory.createAssetBalanceExistenceOperation(
                    for: assetInfo,
                    chainId: chainAsset.chain.chainId,
                    asset: chainAsset.asset
                )
            }
        assetBalanceExistenceWrapper.addDependency(wrapper: assetInfoWrapper)

        let wrapper = CompoundOperationWrapper<AssetBalanceExistence?>(
            targetOperation: assetBalanceExistenceWrapper.targetOperation,
            dependencies: assetInfoWrapper.allOperations + assetBalanceExistenceWrapper.dependencies
        )

        wrapper.targetOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                guard self?.assetExistenceCancellable === wrapper else {
                    return
                }
                self?.assetExistenceCancellable = nil

                do {
                    let assetExistence = try wrapper.targetOperation.extractNoCancellableResultData()
                    self?.basePresenter?.didReceive(assetBalanceExistance: assetExistence)
                } catch {
                    self?.basePresenter?.didReceive(error: .assetExistance(error))
                }
            }
        }

        assetExistenceCancellable = wrapper

        operationQueue.addOperations(
            wrapper.allOperations,
            waitUntilFinished: false
        )
    }
}

extension NominationPoolBondMoreBaseInteractor: NominationPoolBondMoreBaseInteractorInputProtocol {
    func setup() {
        feeProxy.delegate = self

        subscribeAccountBalance()
        subscribePoolMember()
        subscribePrice()
        provideAssetExistence()
    }

    func estimateFee(for points: BigUInt) {
        let reuseIdentifier = String(points)
        feeProxy.estimateFee(
            using: extrinsicService,
            reuseIdentifier: reuseIdentifier,
            setupBy: createExtrinsicClosure(for: points)
        )
    }

    func retrySubscriptions() {
        subscribeAccountBalance()
        subscribePoolMember()
        subscribePrice()
    }

    func retryClaimableRewards() {
        subscribeClaimableRewardsProvider()
    }

    func retryAssetExistance() {
        provideAssetExistence()
    }
}

extension NominationPoolBondMoreBaseInteractor: WalletLocalStorageSubscriber, WalletLocalSubscriptionHandler {
    func handleAssetBalance(
        result: Result<AssetBalance?, Error>,
        accountId _: AccountId,
        chainId _: ChainModel.Id,
        assetId _: AssetModel.Id
    ) {
        switch result {
        case let .success(balance):
            basePresenter?.didReceive(assetBalance: balance)
        case let .failure(error):
            basePresenter?.didReceive(error: .subscription(error, "asset balance"))
        }
    }
}

extension NominationPoolBondMoreBaseInteractor: PriceLocalStorageSubscriber, PriceLocalSubscriptionHandler {
    func handlePrice(
        result: Result<PriceData?, Error>,
        priceId _: AssetModel.PriceId
    ) {
        switch result {
        case let .success(priceData):
            basePresenter?.didReceive(price: priceData)
        case let .failure(error):
            basePresenter?.didReceive(error: .subscription(error, "price"))
        }
    }
}

extension NominationPoolBondMoreBaseInteractor: ExtrinsicFeeProxyDelegate {
    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>, for _: TransactionFeeId) {
        switch result {
        case let .success(dispatchInfo):
            let fee = BigUInt(dispatchInfo.fee)
            basePresenter?.didReceive(fee: fee)
        case let .failure(error):
            basePresenter?.didReceive(error: .fetchFeeFailed(error))
        }
    }
}

extension NominationPoolBondMoreBaseInteractor: SelectedCurrencyDepending {
    func applyCurrency() {
        guard basePresenter != nil,
              let priceId = chainAsset.asset.priceId else {
            return
        }

        priceProvider = subscribeToPrice(for: priceId, currency: selectedCurrency)
    }
}

extension NominationPoolBondMoreBaseInteractor: NPoolsLocalStorageSubscriber, NPoolsLocalSubscriptionHandler {
    func handlePoolMember(
        result: Result<NominationPools.PoolMember?, Error>,
        accountId _: AccountId, chainId _: ChainModel.Id
    ) {
        switch result {
        case let .success(poolMember):
            if currentPoolId != poolMember?.poolId {
                currentPoolId = poolMember?.poolId

                subscribePoolProviders()
                provideBondedAccountId()
            }

            if currentMemberRewardCounter != poolMember?.lastRecordedRewardCounter {
                currentMemberRewardCounter = poolMember?.lastRecordedRewardCounter

                claimableRewardProvider?.refresh()
            }

            basePresenter?.didReceive(poolMember: poolMember)
        case let .failure(error):
            basePresenter?.didReceive(error: .subscription(error, "pool member"))
        }
    }

    func handleRewardPool(
        result: Result<NominationPools.RewardPool?, Error>,
        poolId: NominationPools.PoolId,
        chainId _: ChainModel.Id
    ) {
        guard currentPoolId == poolId else {
            return
        }

        if case let .success(rewardPool) = result, rewardPool?.lastRecordedRewardCounter != currentPoolRewardCounter {
            self.currentPoolRewardCounter = rewardPool?.lastRecordedRewardCounter

            claimableRewardProvider?.refresh()
        }
    }

    func handleBondedPool(
        result: Result<NominationPools.BondedPool?, Error>,
        poolId _: NominationPools.PoolId,
        chainId _: ChainModel.Id
    ) {
        switch result {
        case let .success(bondedPool):
            basePresenter?.didReceive(bondedPool: bondedPool)
        case let .failure(error):
            basePresenter?.didReceive(error: .subscription(error, "bonded pool"))
        }
    }

    func handleClaimableRewards(
        result: Result<BigUInt?, Error>,
        chainId _: ChainModel.Id,
        poolId: NominationPools.PoolId,
        accountId _: AccountId
    ) {
        guard currentPoolId == poolId else {
            return
        }

        switch result {
        case let .success(rewards):
            basePresenter?.didReceive(claimableRewards: rewards)
        case let .failure(error):
            basePresenter?.didReceive(error: .subscription(error, "claimable rewards"))
        }
    }
}

extension NominationPoolBondMoreBaseInteractor: StakingLocalStorageSubscriber, StakingLocalSubscriptionHandler {
    func handleLedgerInfo(
        result: Result<StakingLedger?, Error>,
        accountId _: AccountId,
        chainId _: ChainModel.Id
    ) {
        switch result {
        case let .success(ledger):
            basePresenter?.didReceive(stakingLedger: ledger)
        case let .failure(error):
            basePresenter?.didReceive(error: .subscription(error, "ledger"))
        }
    }
}
