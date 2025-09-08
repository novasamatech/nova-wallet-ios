import Foundation
import BigInt
import Operation_iOS
import Foundation_iOS
import SubstrateSdk

final class StakingNPoolsInteractor: AnyCancellableCleaning, AnyProviderAutoCleaning,
    StakingDurationFetching, NominationPoolsDataProviding {
    weak var presenter: StakingNPoolsInteractorOutputProtocol?

    let state: NPoolsStakingSharedStateProtocol
    let selectedAccount: MetaChainAccountResponse
    let npoolsOperationFactory: NominationPoolsOperationFactoryProtocol
    let runtimeCodingService: RuntimeCodingServiceProtocol
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    let eventCenter: EventCenterProtocol
    let applicationHandler: ApplicationHandlerProtocol
    let operationQueue: OperationQueue

    var stakingLocalSubscriptionFactory: StakingLocalSubscriptionFactoryProtocol {
        state.relaychainLocalSubscriptionFactory
    }

    private var minJoinBondProvider: AnyDataProvider<DecodedBigUInt>?
    private var lastPoolIdProvider: AnyDataProvider<DecodedU32>?
    private var poolMemberProvider: AnyDataProvider<DecodedPoolMember>?
    private var bondedPoolProvider: AnyDataProvider<DecodedBondedPool>?
    private var metadataProvider: AnyDataProvider<DecodedBytes>?
    private var subpoolsProvider: AnyDataProvider<DecodedSubPools>?
    private var rewardPoolProvider: AnyDataProvider<DecodedRewardPool>?
    private var poolLedgerProvider: AnyDataProvider<DecodedLedgerInfo>?
    private var poolNominationProvider: AnyDataProvider<DecodedNomination>?
    private var activeEraProvider: AnyDataProvider<DecodedActiveEra>?
    private var claimableRewardProvider: AnySingleValueProvider<String>?
    private var totalRewardProvider: AnySingleValueProvider<TotalRewardItem>?
    private var priceProvider: StreamableProvider<PriceData>?

    private var activeStakeCancellable: CancellableCall?
    private var durationCancellable: CancellableCall?
    private var bondedAccountIdCancellable: CancellableCall?
    private var activePoolsCancellable: CancellableCall?
    private let eraCountdownCallStore = CancellableCallStore()

    private var lastPoolId: NominationPools.PoolId?
    private var currentPoolId: NominationPools.PoolId?
    private var currentPoolRewardCounter: BigUInt?
    private var currentMemberRewardCounter: BigUInt?
    private var poolAccountId: AccountId?
    private var totalRewardsPeriod: StakingRewardFiltersPeriod?

    var npoolsLocalSubscriptionFactory: NPoolsLocalSubscriptionFactoryProtocol {
        state.npLocalSubscriptionFactory
    }

    var asset: AssetModel {
        state.chainAsset.asset
    }

    var chain: ChainModel {
        state.chainAsset.chain
    }

    var chainId: ChainModel.Id {
        state.chainAsset.chain.chainId
    }

    var accountId: AccountId {
        selectedAccount.chainAccount.accountId
    }

    init(
        state: NPoolsStakingSharedStateProtocol,
        selectedAccount: MetaChainAccountResponse,
        npoolsOperationFactory: NominationPoolsOperationFactoryProtocol,
        runtimeCodingService: RuntimeCodingServiceProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        eventCenter: EventCenterProtocol,
        applicationHandler: ApplicationHandlerProtocol,
        currencyManager: CurrencyManagerProtocol,
        operationQueue: OperationQueue
    ) {
        self.state = state
        self.selectedAccount = selectedAccount
        self.npoolsOperationFactory = npoolsOperationFactory
        self.runtimeCodingService = runtimeCodingService
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.eventCenter = eventCenter
        self.applicationHandler = applicationHandler
        self.operationQueue = operationQueue
        self.currencyManager = currencyManager
    }

    deinit {
        state.throttle()

        clearOperations()
    }

    func clearOperations() {
        clear(cancellable: &activeStakeCancellable)
        clear(cancellable: &durationCancellable)
        clear(cancellable: &bondedAccountIdCancellable)
        clear(cancellable: &activePoolsCancellable)

        eraCountdownCallStore.cancel()
    }

    func setupBaseProviders() {
        bondedPoolProvider = nil
        metadataProvider = nil
        subpoolsProvider = nil
        rewardPoolProvider = nil
        poolLedgerProvider = nil
        poolNominationProvider = nil

        lastPoolId = nil
        currentPoolId = nil
        poolAccountId = nil

        minJoinBondProvider = subscribeMinJoinBond(for: chainId)
        lastPoolIdProvider = subscribeLastPoolId(for: chainId)
        poolMemberProvider = subscribePoolMember(for: accountId, chainId: chainId)
        activeEraProvider = subscribeActiveEra(for: chainId)
    }

    func setupCurrencyProvider() {
        guard let priceId = asset.priceId else {
            presenter?.didReceive(price: nil)
            return
        }

        priceProvider = subscribeToPrice(for: priceId, currency: selectedCurrency)
    }

    func setupProviders(for poolId: NominationPools.PoolId) {
        bondedPoolProvider = subscribeBondedPool(for: poolId, chainId: chainId)
        metadataProvider = subscribePoolMetadata(for: poolId, chainId: chainId)
        subpoolsProvider = subscribeSubPools(for: poolId, chainId: chainId)
        rewardPoolProvider = subscribeRewardPool(for: poolId, chainId: chainId)
    }

    func setupBondedAccountProviders() {
        poolLedgerProvider = nil
        poolNominationProvider = nil

        guard let accountId = poolAccountId else {
            return
        }

        poolLedgerProvider = subscribeLedgerInfo(for: accountId, chainId: chainId)
        poolNominationProvider = subscribeNomination(for: accountId, chainId: chainId)
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
            presenter?.didReceive(error: .claimableRewards(CommonError.dataCorruption))
        }
    }

    func provideStakingDuration() {
        clear(cancellable: &durationCancellable)

        let stakingDurationFactory = state.createStakingDurationOperationFactory()

        let wrapper = stakingDurationFactory.createDurationOperation()

        wrapper.targetOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                guard wrapper === self?.durationCancellable else {
                    return
                }

                self?.durationCancellable = nil

                do {
                    let duration = try wrapper.targetOperation.extractNoCancellableResultData()
                    self?.presenter?.didReceive(duration: duration)
                } catch {
                    self?.presenter?.didReceive(error: .stakingDuration(error))
                }
            }
        }

        durationCancellable = wrapper

        operationQueue.addOperations(wrapper.allOperations, waitUntilFinished: false)
    }

    func provideTotalActiveStake() {
        guard let lastPoolId = lastPoolId else {
            return
        }

        clear(cancellable: &activeStakeCancellable)

        let wrapper = npoolsOperationFactory.createPoolsActiveTotalStakeWrapper(
            for: lastPoolId,
            eraValidatorService: state.eraValidatorService,
            runtimeService: runtimeCodingService
        )

        wrapper.targetOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                guard wrapper === self?.activeStakeCancellable else {
                    return
                }

                self?.activeStakeCancellable = nil

                do {
                    let stake = try wrapper.targetOperation.extractNoCancellableResultData()
                    self?.presenter?.didReceive(totalActiveStake: stake)
                } catch {
                    self?.presenter?.didReceive(error: .totalActiveStake(error))
                }
            }
        }

        activeStakeCancellable = wrapper

        operationQueue.addOperations(wrapper.allOperations, waitUntilFinished: false)
    }

    private func provideBondedAccountId() {
        clear(cancellable: &bondedAccountIdCancellable)

        guard let poolId = currentPoolId else {
            return
        }

        bondedAccountIdCancellable = fetchBondedAccounts(
            for: npoolsOperationFactory,
            poolIds: { [poolId] },
            runtimeService: runtimeCodingService,
            operationQueue: operationQueue,
            completion: { [weak self] result in
                self?.bondedAccountIdCancellable = nil

                switch result {
                case let .success(accountIds):
                    if let accountId = accountIds[poolId] {
                        self?.presenter?.didReceive(poolBondedAccountId: accountId)

                        self?.poolAccountId = accountId
                        self?.setupBondedAccountProviders()
                    }
                case let .failure(error):
                    self?.presenter?.didReceive(error: .subscription(error, "bondedAccountId"))
                }
            }
        )
    }

    private func provideActivePools() {
        clear(cancellable: &activePoolsCancellable)

        let poolsOperation = state.activePoolsService.fetchInfoOperation()

        let mapOperation = ClosureOperation<Set<NominationPools.PoolId>> {
            let activePools = try poolsOperation.extractNoCancellableResultData()
            return Set(activePools.pools.map(\.poolId))
        }

        mapOperation.addDependency(poolsOperation)

        let wrapper = CompoundOperationWrapper(targetOperation: mapOperation, dependencies: [poolsOperation])

        mapOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                guard wrapper === self?.activePoolsCancellable else {
                    return
                }

                self?.activePoolsCancellable = nil

                do {
                    let activePools = try mapOperation.extractNoCancellableResultData()
                    self?.presenter?.didReceive(activePools: activePools)
                } catch {
                    self?.presenter?.didReceive(error: .activePools(error))
                }
            }
        }

        activePoolsCancellable = wrapper

        operationQueue.addOperations(wrapper.allOperations, waitUntilFinished: false)
    }

    private func provideEraCountdown() {
        eraCountdownCallStore.cancel()

        let factory = state.createEraCountdownOperationFactory(for: operationQueue)

        let wrapper = factory.fetchCountdownOperationWrapper()

        executeCancellable(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            backingCallIn: eraCountdownCallStore,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(eraCountdown):
                self?.presenter?.didReceive(eraCountdown: eraCountdown)
            case let .failure(error):
                self?.presenter?.didReceive(error: .eraCountdown(error))
            }
        }
    }
}

extension StakingNPoolsInteractor: StakingNPoolsInteractorInputProtocol {
    func setup() {
        do {
            try state.setup(for: accountId)

            setupBaseProviders()
            setupCurrencyProvider()
            provideStakingDuration()
            provideActivePools()
            provideEraCountdown()

            eventCenter.add(observer: self, dispatchIn: .main)
            applicationHandler.delegate = self
        } catch {
            presenter?.didReceive(error: .stateSetup(error))
        }
    }

    func setupTotalRewards(filter: StakingRewardFiltersPeriod) {
        clear(singleValueProvider: &totalRewardProvider)

        totalRewardsPeriod = filter

        if let address = try? accountId.toAddress(using: chain.chainFormat) {
            if let rewardApi = chain.externalApis?.stakingRewards() {
                let totalRewardInterval = filter.interval
                totalRewardProvider = subscribePoolTotalReward(
                    for: address,
                    startTimestamp: totalRewardInterval.startTimestamp,
                    endTimestamp: totalRewardInterval.endTimestamp,
                    api: rewardApi,
                    assetPrecision: state.chainAsset.assetDisplayInfo.assetPrecision
                )
            } else {
                let zeroReward = TotalRewardItem(
                    address: address,
                    amount: AmountDecimal(value: 0)
                )
                presenter?.didReceive(totalRewards: zeroReward)
            }
        }
    }

    func remakeSubscriptions() {
        setupBaseProviders()
        setupCurrencyProvider()
    }

    func retryActiveStake() {
        provideTotalActiveStake()
    }

    func retryStakingDuration() {
        provideStakingDuration()
    }

    func retryActivePools() {
        provideActivePools()
    }

    func retryEraCountdown() {
        provideEraCountdown()
    }

    func retryClaimableRewards() {
        setupClaimableRewardsProvider()
    }
}

extension StakingNPoolsInteractor: NPoolsLocalStorageSubscriber, NPoolsLocalSubscriptionHandler {
    func handleMinJoinBond(result: Result<BigUInt?, Error>, chainId _: ChainModel.Id) {
        switch result {
        case let .success(optMinJoinBond):
            presenter?.didReceive(minStake: optMinJoinBond)
        case let .failure(error):
            presenter?.didReceive(error: .subscription(error, "minJoinBond"))
        }
    }

    func handleLastPoolId(result: Result<NominationPools.PoolId?, Error>, chainId _: ChainModel.Id) {
        switch result {
        case let .success(optLastPoolId):
            lastPoolId = optLastPoolId
            provideTotalActiveStake()
        case let .failure(error):
            presenter?.didReceive(error: .subscription(error, "lastPoolId"))
        }
    }

    func handlePoolMember(
        result: Result<NominationPools.PoolMember?, Error>,
        accountId _: AccountId,
        chainId _: ChainModel.Id
    ) {
        switch result {
        case let .success(optPoolMember):
            presenter?.didReceive(poolMember: optPoolMember)

            if let poolId = optPoolMember?.poolId, currentPoolId != poolId {
                self.currentPoolId = poolId

                setupProviders(for: poolId)
                setupClaimableRewardsProvider()
                provideBondedAccountId()
            }

            if currentMemberRewardCounter != optPoolMember?.lastRecordedRewardCounter {
                currentMemberRewardCounter = optPoolMember?.lastRecordedRewardCounter

                claimableRewardProvider?.refresh()
            }
        case let .failure(error):
            presenter?.didReceive(error: .subscription(error, "poolMember"))
        }
    }

    func handleBondedPool(
        result: Result<NominationPools.BondedPool?, Error>,
        poolId _: NominationPools.PoolId,
        chainId _: ChainModel.Id
    ) {
        switch result {
        case let .success(optBondedPool):
            presenter?.didReceive(bondedPool: optBondedPool)
        case let .failure(error):
            presenter?.didReceive(error: .subscription(error, "bondedPool"))
        }
    }

    func handlePoolMetadata(
        result: Result<Data?, Error>,
        poolId _: NominationPools.PoolId,
        chainId _: ChainModel.Id
    ) {
        switch result {
        case let .success(optPoolMetadata):
            presenter?.didReceive(poolMetadata: optPoolMetadata)
        case let .failure(error):
            presenter?.didReceive(error: .subscription(error, "poolMetadata"))
        }
    }

    func handleSubPools(
        result: Result<NominationPools.SubPools?, Error>,
        poolId _: NominationPools.PoolId,
        chainId _: ChainModel.Id
    ) {
        switch result {
        case let .success(optSubPools):
            presenter?.didReceive(subPools: optSubPools)
        case let .failure(error):
            presenter?.didReceive(error: .subscription(error, "subPools"))
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
            presenter?.didRecieve(claimableRewards: rewards)
        case let .failure(error):
            presenter?.didReceive(error: .claimableRewards(error))
        }
    }

    func handlePoolTotalReward(
        result: Result<TotalRewardItem?, Error>,
        for _: AccountAddress,
        startTimestamp: Int64?,
        endTimestamp: Int64?,
        api _: Set<LocalChainExternalApi>
    ) {
        guard
            let interval = totalRewardsPeriod?.interval,
            startTimestamp == interval.startTimestamp,
            endTimestamp == interval.endTimestamp else {
            return
        }

        switch result {
        case let .success(totalRewards):
            presenter?.didReceive(totalRewards: totalRewards)
        case let .failure(error):
            presenter?.didReceive(error: .totalRewards(error))
        }
    }
}

extension StakingNPoolsInteractor: StakingLocalStorageSubscriber, StakingLocalSubscriptionHandler {
    func handleActiveEra(result: Result<Staking.ActiveEraInfo?, Error>, chainId _: ChainModel.Id) {
        switch result {
        case let .success(optActiveEra):
            presenter?.didReceive(activeEra: optActiveEra)
        case let .failure(error):
            presenter?.didReceive(error: .subscription(error, "activeEra"))
        }
    }

    func handleNomination(result: Result<Staking.Nomination?, Error>, accountId _: AccountId, chainId _: ChainModel.Id) {
        switch result {
        case let .success(optNomination):
            presenter?.didReceive(poolNomination: optNomination)
        case let .failure(error):
            presenter?.didReceive(error: .subscription(error, "poolNomination"))
        }
    }

    func handleLedgerInfo(result: Result<Staking.Ledger?, Error>, accountId _: AccountId, chainId _: ChainModel.Id) {
        switch result {
        case let .success(optLedger):
            presenter?.didReceive(poolLedger: optLedger)
        case let .failure(error):
            presenter?.didReceive(error: .subscription(error, "stakingLedger"))
        }
    }
}

extension StakingNPoolsInteractor: PriceLocalStorageSubscriber, PriceLocalSubscriptionHandler {
    func handlePrice(result: Result<PriceData?, Error>, priceId _: AssetModel.PriceId) {
        switch result {
        case let .success(optPrice):
            presenter?.didReceive(price: optPrice)
        case let .failure(error):
            presenter?.didReceive(error: .subscription(error, "price"))
        }
    }
}

extension StakingNPoolsInteractor: EventVisitorProtocol {
    func processEraStakersInfoChanged(event _: EraStakersInfoChanged) {
        provideTotalActiveStake()
        provideActivePools()
    }

    func processBlockTimeChanged(event _: BlockTimeChanged) {
        provideStakingDuration()
        provideEraCountdown()
    }
}

extension StakingNPoolsInteractor: SelectedCurrencyDepending {
    func applyCurrency() {
        guard presenter != nil else {
            return
        }

        setupCurrencyProvider()
    }
}

extension StakingNPoolsInteractor: ApplicationHandlerDelegate {
    func didReceiveDidBecomeActive(notification _: Notification) {
        priceProvider?.refresh()
    }
}
