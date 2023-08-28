import Foundation
import RobinHood
import BigInt
import SubstrateSdk

class NPoolsUnstakeBaseInteractor: AnyCancellableCleaning, NominationPoolsDataProviding {
    weak var basePresenter: NPoolsUnstakeBaseInteractorOutputProtocol?

    let selectedAccount: MetaChainAccountResponse
    let chainAsset: ChainAsset
    let extrinsicService: ExtrinsicServiceProtocol
    let feeProxy: ExtrinsicFeeProxyProtocol

    let npoolsOperationFactory: NominationPoolsOperationFactoryProtocol
    let npoolsLocalSubscriptionFactory: NPoolsLocalSubscriptionFactoryProtocol
    let stakingLocalSubscriptionFactory: StakingLocalSubscriptionFactoryProtocol
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    let walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol
    let eraCountdownOperationFactory: EraCountdownOperationFactoryProtocol
    let unstakeLimitsFactory: NPoolsUnstakeOperationFactoryProtocol
    let durationFactory: StakingDurationOperationFactoryProtocol
    let connection: JSONRPCEngine
    let runtimeService: RuntimeCodingServiceProtocol
    let eventCenter: EventCenterProtocol
    let operationQueue: OperationQueue

    var accountId: AccountId { selectedAccount.chainAccount.accountId }
    var chainId: ChainModel.Id { chainAsset.chain.chainId }
    var asset: AssetModel { chainAsset.asset }
    var assetId: AssetModel.Id { asset.assetId }

    private var poolMemberProvider: AnyDataProvider<DecodedPoolMember>?
    private var balanceProvider: StreamableProvider<AssetBalance>?
    private var priceProvider: StreamableProvider<PriceData>?
    private var bondedPoolProvider: AnyDataProvider<DecodedBondedPool>?
    private var poolLedgerProvider: AnyDataProvider<DecodedLedgerInfo>?
    private var rewardPoolProvider: AnyDataProvider<DecodedRewardPool>?
    private var claimableRewardProvider: AnySingleValueProvider<String>?
    private var minStakeProvider: AnyDataProvider<DecodedBigUInt>?

    private var bondedAccountIdCancellable: CancellableCall?
    private var eraCountdownCancellable: CancellableCall?
    private var durationCancellable: CancellableCall?
    private var unstakeLimitsCancellable: CancellableCall?

    private var currentPoolId: NominationPools.PoolId?
    private var currentPoolRewardCounter: BigUInt?
    private var currentMemberRewardCounter: BigUInt?
    private var poolAccountId: AccountId?

    init(
        selectedAccount: MetaChainAccountResponse,
        chainAsset: ChainAsset,
        extrinsicService: ExtrinsicServiceProtocol,
        feeProxy: ExtrinsicFeeProxyProtocol,
        npoolsLocalSubscriptionFactory: NPoolsLocalSubscriptionFactoryProtocol,
        stakingLocalSubscriptionFactory: StakingLocalSubscriptionFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        connection: JSONRPCEngine,
        runtimeService: RuntimeCodingServiceProtocol,
        eraCountdownOperationFactory: EraCountdownOperationFactoryProtocol,
        durationFactory: StakingDurationOperationFactoryProtocol,
        npoolsOperationFactory: NominationPoolsOperationFactoryProtocol,
        unstakeLimitsFactory: NPoolsUnstakeOperationFactoryProtocol,
        eventCenter: EventCenterProtocol,
        currencyManager: CurrencyManagerProtocol,
        operationQueue: OperationQueue
    ) {
        self.selectedAccount = selectedAccount
        self.chainAsset = chainAsset
        self.extrinsicService = extrinsicService
        self.feeProxy = feeProxy
        self.npoolsLocalSubscriptionFactory = npoolsLocalSubscriptionFactory
        self.stakingLocalSubscriptionFactory = stakingLocalSubscriptionFactory
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.walletLocalSubscriptionFactory = walletLocalSubscriptionFactory
        self.npoolsOperationFactory = npoolsOperationFactory
        self.connection = connection
        self.runtimeService = runtimeService
        self.eraCountdownOperationFactory = eraCountdownOperationFactory
        self.durationFactory = durationFactory
        self.unstakeLimitsFactory = unstakeLimitsFactory
        self.operationQueue = operationQueue
        self.eventCenter = eventCenter
        self.currencyManager = currencyManager
    }

    deinit {
        eventCenter.remove(observer: self)

        clearCancellable()
    }

    func clearCancellable() {
        clear(cancellable: &bondedAccountIdCancellable)
        clear(cancellable: &eraCountdownCancellable)
        clear(cancellable: &durationCancellable)
        clear(cancellable: &unstakeLimitsCancellable)
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
                        self?.setupBondedAccountProviders()
                    }
                case let .failure(error):
                    self?.basePresenter?.didReceive(error: .subscription(error, "bondedAccountId"))
                }
            }
        )
    }

    func setupPoolProviders() {
        guard let poolId = currentPoolId else {
            return
        }

        bondedPoolProvider = subscribeBondedPool(for: poolId, chainId: chainId)
        rewardPoolProvider = subscribeRewardPool(for: poolId, chainId: chainId)

        setupClaimableRewardsProvider()
    }

    func setupBondedAccountProviders() {
        poolLedgerProvider = nil

        guard let accountId = poolAccountId else {
            return
        }

        poolLedgerProvider = subscribeLedgerInfo(for: accountId, chainId: chainId)
    }

    func setupClaimableRewardsProvider() {
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

    func setupCurrencyProvider() {
        guard let priceId = asset.priceId else {
            basePresenter?.didReceive(price: nil)
            return
        }

        priceProvider = subscribeToPrice(for: priceId, currency: selectedCurrency)
    }

    func setupBaseProviders() {
        bondedPoolProvider = nil
        poolLedgerProvider = nil
        rewardPoolProvider = nil
        claimableRewardProvider = nil

        poolMemberProvider = subscribePoolMember(for: accountId, chainId: chainId)
        balanceProvider = subscribeToAssetBalanceProvider(for: accountId, chainId: chainId, assetId: assetId)
        minStakeProvider = subscribeMinJoinBond(for: chainId)

        setupCurrencyProvider()
    }

    func provideEraCountdown() {
        clear(cancellable: &eraCountdownCancellable)

        let wrapper = eraCountdownOperationFactory.fetchCountdownOperationWrapper(
            for: connection,
            runtimeService: runtimeService
        )

        wrapper.targetOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                guard wrapper === self?.eraCountdownCancellable else {
                    return
                }

                self?.eraCountdownCancellable = nil

                do {
                    let eraCountdown = try wrapper.targetOperation.extractNoCancellableResultData()
                    self?.basePresenter?.didReceive(eraCountdown: eraCountdown)
                } catch {
                    self?.basePresenter?.didReceive(error: .eraCountdown(error))
                }
            }
        }

        eraCountdownCancellable = wrapper

        operationQueue.addOperations(wrapper.allOperations, waitUntilFinished: false)
    }

    func provideStakingDuration() {
        clear(cancellable: &durationCancellable)

        let wrapper = durationFactory.createDurationOperation(from: runtimeService)

        wrapper.targetOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                guard wrapper === self?.durationCancellable else {
                    return
                }

                self?.durationCancellable = nil

                do {
                    let duration = try wrapper.targetOperation.extractNoCancellableResultData()
                    self?.basePresenter?.didReceive(stakingDuration: duration)
                } catch {
                    self?.basePresenter?.didReceive(error: .stakingDuration(error))
                }
            }
        }

        durationCancellable = wrapper

        operationQueue.addOperations(wrapper.allOperations, waitUntilFinished: false)
    }

    func provideUnstakingLimits() {
        clear(cancellable: &unstakeLimitsCancellable)

        let wrapper = unstakeLimitsFactory.createLimitsWrapper(
            for: chainAsset.chain,
            runtimeService: runtimeService
        )

        wrapper.targetOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                guard self?.unstakeLimitsCancellable === wrapper else {
                    return
                }

                self?.unstakeLimitsCancellable = nil

                do {
                    let limits = try wrapper.targetOperation.extractNoCancellableResultData()
                    self?.basePresenter?.didReceive(unstakingLimits: limits)
                } catch {
                    self?.basePresenter?.didReceive(error: .unstakeLimits(error))
                }
            }
        }

        unstakeLimitsCancellable = wrapper

        operationQueue.addOperations(wrapper.allOperations, waitUntilFinished: false)
    }

    func createExtrinsicClosure(for points: BigUInt, accountId: AccountId) -> ExtrinsicBuilderClosure {
        { builder in
            let call = NominationPools.UnbondCall(
                memberAccount: .accoundId(accountId),
                unbondingPoints: points
            )
            return try builder.adding(call: call.runtimeCall())
        }
    }
}

extension NPoolsUnstakeBaseInteractor: NPoolsUnstakeBaseInteractorInputProtocol {
    func setup() {
        setupBaseProviders()
        provideEraCountdown()
        provideStakingDuration()
        provideUnstakingLimits()

        feeProxy.delegate = self
        eventCenter.add(observer: self, dispatchIn: .main)
    }

    func retrySubscriptions() {
        setupBaseProviders()
    }

    func retryStakingDuration() {
        provideStakingDuration()
    }

    func retryEraCountdown() {
        provideEraCountdown()
    }

    func retryClaimableRewards() {
        setupClaimableRewardsProvider()
    }

    func retryUnstakeLimits() {
        provideUnstakingLimits()
    }

    func estimateFee(for points: BigUInt) {
        let identifier = String(points)

        feeProxy.estimateFee(
            using: extrinsicService,
            reuseIdentifier: identifier,
            setupBy: createExtrinsicClosure(for: points, accountId: accountId)
        )
    }
}

extension NPoolsUnstakeBaseInteractor: ExtrinsicFeeProxyDelegate {
    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>, for _: TransactionFeeId) {
        switch result {
        case let .success(dispatchInfo):
            basePresenter?.didReceive(fee: BigUInt(dispatchInfo.fee))
        case let .failure(error):
            basePresenter?.didReceive(error: .fee(error))
        }
    }
}

extension NPoolsUnstakeBaseInteractor: NPoolsLocalStorageSubscriber, NPoolsLocalSubscriptionHandler {
    func handlePoolMember(
        result: Result<NominationPools.PoolMember?, Error>,
        accountId _: AccountId, chainId _: ChainModel.Id
    ) {
        switch result {
        case let .success(optPoolMember):
            if currentPoolId != optPoolMember?.poolId {
                currentPoolId = optPoolMember?.poolId

                setupPoolProviders()
                provideBondedAccountId()
            }

            if currentMemberRewardCounter != optPoolMember?.lastRecordedRewardCounter {
                currentMemberRewardCounter = optPoolMember?.lastRecordedRewardCounter

                claimableRewardProvider?.refresh()
            }

            basePresenter?.didReceive(poolMember: optPoolMember)
        case let .failure(error):
            basePresenter?.didReceive(error: .subscription(error, "pool member"))
        }
    }

    func handleClaimableRewards(
        result: Result<BigUInt?, Error>,
        chainId _: ChainModel.Id,
        poolId _: NominationPools.PoolId,
        accountId _: AccountId
    ) {
        switch result {
        case let .success(rewards):
            basePresenter?.didReceive(claimableRewards: rewards)
        case let .failure(error):
            basePresenter?.didReceive(error: .claimableRewards(error))
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

    func handleMinJoinBond(result: Result<BigUInt?, Error>, chainId _: ChainModel.Id) {
        switch result {
        case let .success(minStake):
            basePresenter?.didReceive(minStake: minStake)
        case let .failure(error):
            basePresenter?.didReceive(error: .subscription(error, "min stake"))
        }
    }
}

extension NPoolsUnstakeBaseInteractor: StakingLocalStorageSubscriber, StakingLocalSubscriptionHandler {
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

extension NPoolsUnstakeBaseInteractor: WalletLocalStorageSubscriber, WalletLocalSubscriptionHandler {
    func handleAssetBalance(
        result: Result<AssetBalance?, Error>,
        accountId _: AccountId, chainId _: ChainModel.Id,
        assetId _: AssetModel.Id
    ) {
        switch result {
        case let .success(assetBalance):
            basePresenter?.didReceive(assetBalance: assetBalance)
        case let .failure(error):
            basePresenter?.didReceive(error: .subscription(error, "balance"))
        }
    }
}

extension NPoolsUnstakeBaseInteractor: PriceLocalStorageSubscriber, PriceLocalSubscriptionHandler {
    func handlePrice(result: Result<PriceData?, Error>, priceId _: AssetModel.PriceId) {
        switch result {
        case let .success(priceData):
            basePresenter?.didReceive(price: priceData)
        case let .failure(error):
            basePresenter?.didReceive(error: .subscription(error, "price"))
        }
    }
}

extension NPoolsUnstakeBaseInteractor: EventVisitorProtocol {
    func processBlockTimeChanged(event _: BlockTimeChanged) {
        provideEraCountdown()
        provideStakingDuration()
    }
}

extension NPoolsUnstakeBaseInteractor: SelectedCurrencyDepending {
    func applyCurrency() {
        guard basePresenter != nil else {
            return
        }

        setupCurrencyProvider()
    }
}
