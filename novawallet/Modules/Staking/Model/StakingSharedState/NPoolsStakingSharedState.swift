import Foundation

protocol NPoolsStakingSharedStateProtocol: AnyObject {
    var chainAsset: ChainAsset { get }
    var timeModel: StakingTimeModel { get }

    var relaychainGlobalSubscriptionService: StakingRemoteSubscriptionServiceProtocol { get }
    var relaychainLocalSubscriptionFactory: StakingLocalSubscriptionFactoryProtocol { get }
    var eraValidatorService: EraValidatorServiceProtocol { get }
    var rewardCalculatorService: RewardCalculatorServiceProtocol { get }

    var npRemoteSubscriptionService: NominationPoolsRemoteSubscriptionServiceProtocol { get }
    var npAccountSubscriptionServiceFactory: NominationPoolsAccountUpdatingFactoryProtocol { get }
    var activePoolsService: EraNominationPoolsServiceProtocol { get }
    var npLocalSubscriptionFactory: NPoolsLocalSubscriptionFactoryProtocol { get }

    func setup(for accountId: AccountId) throws
    func throttle()

    func createEraCountdownOperationFactory(
        for operationQueue: OperationQueue
    ) -> EraCountdownOperationFactoryProtocol

    func createStakingDurationOperationFactory() -> StakingDurationOperationFactoryProtocol
}

final class NPoolsStakingSharedState {
    let chainAsset: ChainAsset
    let relaychainGlobalSubscriptionService: StakingRemoteSubscriptionServiceProtocol
    let timeModel: StakingTimeModel
    let relaychainLocalSubscriptionFactory: StakingLocalSubscriptionFactoryProtocol
    let eraValidatorService: EraValidatorServiceProtocol
    let rewardCalculatorService: RewardCalculatorServiceProtocol
    let npRemoteSubscriptionService: NominationPoolsRemoteSubscriptionServiceProtocol
    let npAccountSubscriptionServiceFactory: NominationPoolsAccountUpdatingFactoryProtocol
    let activePoolsService: EraNominationPoolsServiceProtocol
    let npLocalSubscriptionFactory: NPoolsLocalSubscriptionFactoryProtocol
    let logger: LoggerProtocol

    var chainId: ChainModel.Id {
        chainAsset.chain.chainId
    }

    private var accountService: NominationPoolsAccountUpdatingService?
    private var relaychainGlobalSubscription: UUID?
    private var npoolsGlobalSubscription: UUID?

    private let consensusDependingFactory: RelaychainConsensusStateDepending

    init(
        chainAsset: ChainAsset,
        chainRegistry: ChainRegistryProtocol,
        relaychainGlobalSubscriptionService: StakingRemoteSubscriptionServiceProtocol,
        timeModel: StakingTimeModel,
        relaychainLocalSubscriptionFactory: StakingLocalSubscriptionFactoryProtocol,
        eraValidatorService: EraValidatorServiceProtocol,
        rewardCalculatorService: RewardCalculatorServiceProtocol,
        npRemoteSubscriptionService: NominationPoolsRemoteSubscriptionServiceProtocol,
        npAccountSubscriptionServiceFactory: NominationPoolsAccountUpdatingFactoryProtocol,
        activePoolsService: EraNominationPoolsServiceProtocol,
        npLocalSubscriptionFactory: NPoolsLocalSubscriptionFactoryProtocol,
        logger: LoggerProtocol
    ) {
        self.chainAsset = chainAsset
        self.relaychainGlobalSubscriptionService = relaychainGlobalSubscriptionService
        self.timeModel = timeModel
        self.relaychainLocalSubscriptionFactory = relaychainLocalSubscriptionFactory
        self.eraValidatorService = eraValidatorService
        self.rewardCalculatorService = rewardCalculatorService
        self.npRemoteSubscriptionService = npRemoteSubscriptionService
        self.npAccountSubscriptionServiceFactory = npAccountSubscriptionServiceFactory
        self.activePoolsService = activePoolsService
        self.npLocalSubscriptionFactory = npLocalSubscriptionFactory
        self.logger = logger

        consensusDependingFactory = RelaychainConsensusStateDependingFactory(
            chainRegistry: chainRegistry
        )
    }
}

extension NPoolsStakingSharedState: NPoolsStakingSharedStateProtocol {
    func setup(for accountId: AccountId) throws {
        accountService = try npAccountSubscriptionServiceFactory.create(for: accountId, chainAsset: chainAsset)
        accountService?.setup()

        relaychainGlobalSubscription = relaychainGlobalSubscriptionService.attachToGlobalData(
            for: chainId,
            queue: .main
        ) { [weak self] result in
            switch result {
            case .success:
                self?.logger.debug("Relaychain global data subscription succeeded")
            case let .failure(error):
                self?.logger.error("Relaychain global data subscription failed: \(error)")
            }
        }

        npoolsGlobalSubscription = npRemoteSubscriptionService.attachToGlobalData(
            for: chainId,
            queue: .main
        ) { [weak self] result in
            switch result {
            case .success:
                self?.logger.debug("Nomination pools global data subscription succeeded")
            case let .failure(error):
                self?.logger.error("Nomination pools global data subscription failed: \(error)")
            }
        }

        eraValidatorService.setup()
        rewardCalculatorService.setup()
        activePoolsService.setup()
        timeModel.blockTimeService?.setup()
    }

    func throttle() {
        accountService?.throttle()
        accountService = nil

        if let subscription = relaychainGlobalSubscription {
            relaychainGlobalSubscriptionService.detachFromGlobalData(
                for: subscription,
                chainId: chainId,
                queue: .main
            ) { [weak self] result in
                switch result {
                case .success:
                    self?.logger.debug("Relaychain global data unsubscribe succeeded")
                case let .failure(error):
                    self?.logger.error("Relaychain global data unsubscribe failed: \(error)")
                }
            }
        }

        if let subscription = npoolsGlobalSubscription {
            npRemoteSubscriptionService.detachFromGlobalData(
                for: subscription,
                chainId: chainId,
                queue: .main
            ) { [weak self] result in
                switch result {
                case .success:
                    self?.logger.debug("Nomination pools global data unsubscribe succeeded")
                case let .failure(error):
                    self?.logger.error("Nomination pools global data unsubscribe failed: \(error)")
                }
            }
        }

        eraValidatorService.throttle()
        rewardCalculatorService.throttle()
        activePoolsService.throttle()
        timeModel.blockTimeService?.throttle()
    }

    func createEraCountdownOperationFactory(
        for operationQueue: OperationQueue
    ) -> EraCountdownOperationFactoryProtocol {
        consensusDependingFactory.createEraCountdownOperationFactory(
            for: chainAsset.chain,
            timeModel: timeModel,
            operationQueue: operationQueue
        )
    }

    func createStakingDurationOperationFactory() -> StakingDurationOperationFactoryProtocol {
        consensusDependingFactory.createStakingDurationOperationFactory(
            for: chainAsset.chain,
            timeModel: timeModel
        )
    }
}
