import Foundation
import Operation_iOS
import BigInt
import SubstrateSdk

class NPoolsUnstakeBaseInteractor: AnyCancellableCleaning, NominationPoolsDataProviding, RuntimeConstantFetching,
    NominationPoolStakingMigrating, AnyProviderAutoCleaning {
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
    private var delegatedStakingProvider: AnyDataProvider<DecodedDelegatedStakingDelegator>?
    private var cancellableNeedsMigration = CancellableCallStore()

    private var bondedAccountIdCancellable: CancellableCall?
    private let eraCountdownCallStore = CancellableCallStore()
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
        clearCancellable()
    }

    func clearCancellable() {
        clear(cancellable: &bondedAccountIdCancellable)
        clear(cancellable: &durationCancellable)
        clear(cancellable: &unstakeLimitsCancellable)

        eraCountdownCallStore.cancel()
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

        clear(dataProvider: &delegatedStakingProvider)

        delegatedStakingProvider = subscribeDelegatedStaking(for: accountId, chainId: chainId)

        setupCurrencyProvider()
    }

    func provideEraCountdown() {
        eraCountdownCallStore.cancel()

        let wrapper = eraCountdownOperationFactory.fetchCountdownOperationWrapper()

        executeCancellable(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            backingCallIn: eraCountdownCallStore,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(eraCountdown):
                self?.basePresenter?.didReceive(eraCountdown: eraCountdown)
            case let .failure(error):
                self?.basePresenter?.didReceive(error: .eraCountdown(error))
            }
        }
    }

    func provideStakingDuration() {
        clear(cancellable: &durationCancellable)

        let wrapper = durationFactory.createDurationOperation()

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

    func createExtrinsicClosure(
        for points: BigUInt,
        accountId: AccountId,
        needsMigration: Bool
    ) -> ExtrinsicBuilderClosure {
        { builder in
            let currentBuilder = try NominationPools.migrateIfNeeded(
                needsMigration,
                accountId: accountId,
                builder: builder
            )

            let call = NominationPools.UnbondCall(
                memberAccount: .accoundId(accountId),
                unbondingPoints: points
            )
            return try currentBuilder.adding(call: call.runtimeCall())
        }
    }

    func provideExistentialDeposit() {
        fetchConstant(
            for: .existentialDeposit,
            runtimeCodingService: runtimeService,
            operationQueue: operationQueue
        ) { [weak self] (result: Result<BigUInt, Error>) in
            switch result {
            case let .success(existentialDeposit):
                self?.basePresenter?.didReceive(existentialDeposit: existentialDeposit)
            case let .failure(error):
                self?.basePresenter?.didReceive(error: .existentialDeposit(error))
            }
        }
    }
}

extension NPoolsUnstakeBaseInteractor: NPoolsUnstakeBaseInteractorInputProtocol {
    func setup() {
        setupBaseProviders()
        provideEraCountdown()
        provideStakingDuration()
        provideUnstakingLimits()
        provideExistentialDeposit()

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

    func retryExistentialDeposit() {
        provideExistentialDeposit()
    }

    func estimateFee(for points: BigUInt, needsMigration: Bool) {
        let identifier = String(points) + "-" + "\(needsMigration)"

        feeProxy.estimateFee(
            using: extrinsicService,
            reuseIdentifier: identifier,
            setupBy: createExtrinsicClosure(
                for: points,
                accountId: accountId,
                needsMigration: needsMigration
            )
        )
    }
}

extension NPoolsUnstakeBaseInteractor: ExtrinsicFeeProxyDelegate {
    func didReceiveFee(result: Result<ExtrinsicFeeProtocol, Error>, for _: TransactionFeeId) {
        switch result {
        case let .success(feeInfo):
            basePresenter?.didReceive(fee: feeInfo)
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

    func handleDelegatedStaking(
        result: Result<DelegatedStakingPallet.Delegation?, Error>,
        accountId _: AccountId,
        chainId _: ChainModel.Id
    ) {
        switch result {
        case let .success(delegation):
            cancellableNeedsMigration.cancel()

            needsPoolStakingMigration(
                for: delegation,
                runtimeProvider: runtimeService,
                cancellableStore: cancellableNeedsMigration,
                operationQueue: operationQueue
            ) { [weak self] result in
                switch result {
                case let .success(needsMigration):
                    self?.basePresenter?.didReceive(needsMigration: needsMigration)
                case let .failure(error):
                    self?.basePresenter?.didReceive(error: .subscription(error, "Needs Migration"))
                }
            }
        case let .failure(error):
            basePresenter?.didReceive(error: .subscription(error, "Delegated Staking"))
        }
    }
}

extension NPoolsUnstakeBaseInteractor: StakingLocalStorageSubscriber, StakingLocalSubscriptionHandler {
    func handleLedgerInfo(
        result: Result<Staking.Ledger?, Error>,
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
        accountId: AccountId,
        chainId: ChainModel.Id,
        assetId: AssetModel.Id
    ) {
        switch result {
        case let .success(assetBalance):
            // we can have case when user have np staking but no native balance
            let balanceOrZero = assetBalance ?? .createZero(
                for: .init(chainId: chainId, assetId: assetId),
                accountId: accountId
            )
            basePresenter?.didReceive(assetBalance: balanceOrZero)
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
