import Foundation
import BigInt
import RobinHood
import SoraFoundation

final class StakingNPoolsInteractor: AnyCancellableCleaning, StakingDurationFetching {
    weak var presenter: StakingNPoolsInteractorOutputProtocol?

    let state: NPoolsStakingSharedStateProtocol
    let selectedAccount: MetaChainAccountResponse
    let npoolsOperationFactory: NominationPoolsOperationFactoryProtocol
    let runtimeCodingService: RuntimeCodingServiceProtocol
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    let eventCenter: EventCenterProtocol
    let applicationHandler: ApplicationHandlerProtocol
    let operationQueue: OperationQueue

    private var minJoinBondProvider: AnyDataProvider<DecodedBigUInt>?
    private var lastPoolIdProvider: AnyDataProvider<DecodedU32>?
    private var poolMemberProvider: AnyDataProvider<DecodedPoolMember>?
    private var bondedPoolProvider: AnyDataProvider<DecodedBondedPool>?
    private var metadataProvider: AnyDataProvider<DecodedBytes>?
    private var subpoolsProvider: AnyDataProvider<DecodedSubPools>?
    private var rewardPoolProvider: AnyDataProvider<DecodedRewardPool>?
    private var priceProvider: StreamableProvider<PriceData>?

    private var activeStakeCancellable: CancellableCall?
    private var durationCancellable: CancellableCall?
    private var lastPoolId: NominationPools.PoolId?

    var npoolsLocalSubscriptionFactory: NPoolsLocalSubscriptionFactoryProtocol {
        state.npLocalSubscriptionFactory
    }

    var asset: AssetModel {
        state.chainAsset.asset
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
    }

    deinit {
        state.throttle()

        clearOperations()
    }

    func clearOperations() {
        clear(cancellable: &activeStakeCancellable)
        clear(cancellable: &durationCancellable)
    }

    func setupBaseProviders() {
        bondedPoolProvider = nil
        metadataProvider = nil
        subpoolsProvider = nil
        rewardPoolProvider = nil

        minJoinBondProvider = subscribeMinJoinBond(for: chainId)
        lastPoolIdProvider = subscribeLastPoolId(for: chainId)
        poolMemberProvider = subscribePoolMember(for: accountId, chainId: chainId)
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

    func provideStakingDuration() {
        clear(cancellable: &durationCancellable)

        let stakingDurationFactory = state.createStakingDurationOperationFactory()

        let wrapper = stakingDurationFactory.createDurationOperation(from: runtimeCodingService)

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
}

extension StakingNPoolsInteractor: StakingNPoolsInteractorInputProtocol {
    func setup() {
        do {
            try state.setup(for: accountId)

            setupBaseProviders()
            setupCurrencyProvider()
            provideStakingDuration()

            eventCenter.add(observer: self, dispatchIn: .main)
            applicationHandler.delegate = self
        } catch {
            presenter?.didReceive(error: .stateSetup(error))
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
            if let poolId = optPoolMember?.poolId {
                setupProviders(for: poolId)
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
            break
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
            break
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
            break
        case let .failure(error):
            presenter?.didReceive(error: .subscription(error, "subPools"))
        }
    }

    func handleRewardPool(
        result: Result<NominationPools.RewardPool?, Error>,
        poolId _: NominationPools.PoolId,
        chainId _: ChainModel.Id
    ) {
        switch result {
        case let .success(optRewardPool):
            break
        case let .failure(error):
            presenter?.didReceive(error: .subscription(error, "rewardPool"))
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
    }

    func processBlockTimeChanged(event _: BlockTimeChanged) {
        provideStakingDuration()
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
