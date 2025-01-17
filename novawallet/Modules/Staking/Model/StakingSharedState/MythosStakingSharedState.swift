import Foundation

protocol MythosStakingSharedStateProtocol {
    var stakingOption: Multistaking.ChainAssetOption { get }
    var chainRegistry: ChainRegistryProtocol { get }
    var stakingLocalSubscriptionFactory: MythosStakingLocalSubscriptionFactoryProtocol { get }
    var generalLocalSubscriptionFactory: GeneralStorageSubscriptionFactoryProtocol { get }
    var blockTimeService: BlockTimeEstimationServiceProtocol { get }

    var logger: LoggerProtocol { get }

    var sharedOperation: SharedOperationProtocol? { get }

    func setup(for accountId: AccountId?)
    func throttle()
    func startSharedOperation() -> SharedOperationProtocol
}

final class MythosStakingSharedState {
    let stakingOption: Multistaking.ChainAssetOption
    let chainRegistry: ChainRegistryProtocol
    let blockTimeService: BlockTimeEstimationServiceProtocol
    let globalRemoteSubscriptionService: StakingRemoteSubscriptionServiceProtocol
    let generalLocalSubscriptionFactory: GeneralStorageSubscriptionFactoryProtocol
    let stakingLocalSubscriptionFactory: MythosStakingLocalSubscriptionFactoryProtocol
    let logger: LoggerProtocol

    weak var sharedOperation: SharedOperationProtocol?

    private var globalRemoteSubscription: UUID?

    init(
        stakingOption: Multistaking.ChainAssetOption,
        chainRegistry: ChainRegistryProtocol,
        stakingLocalSubscriptionFactory: MythosStakingLocalSubscriptionFactoryProtocol,
        globalRemoteSubscriptionService: StakingRemoteSubscriptionServiceProtocol,
        blockTimeService: BlockTimeEstimationServiceProtocol,
        generalLocalSubscriptionFactory: GeneralStorageSubscriptionFactoryProtocol,
        logger: LoggerProtocol
    ) {
        self.stakingOption = stakingOption
        self.chainRegistry = chainRegistry
        self.stakingLocalSubscriptionFactory = stakingLocalSubscriptionFactory
        self.globalRemoteSubscriptionService = globalRemoteSubscriptionService
        self.blockTimeService = blockTimeService
        self.generalLocalSubscriptionFactory = generalLocalSubscriptionFactory
        self.logger = logger
    }
}

extension MythosStakingSharedState: MythosStakingSharedStateProtocol {
    func setup(for _: AccountId?) {
        let chainId = stakingOption.chainAsset.chain.chainId

        globalRemoteSubscription = globalRemoteSubscriptionService.attachToGlobalData(
            for: chainId,
            queue: .main
        ) { [weak self] result in
            switch result {
            case .success:
                self?.logger.debug("Mythos staking global remote subscription succeeded")
            case let .failure(error):
                self?.logger.error("Mythos staking global remote subscription failed: \(error)")
            }
        }

        blockTimeService.setup()
    }

    func throttle() {
        let chainId = stakingOption.chainAsset.chain.chainId

        if let globalRemoteSubscription = globalRemoteSubscription {
            globalRemoteSubscriptionService.detachFromGlobalData(
                for: globalRemoteSubscription,
                chainId: chainId,
                queue: nil,
                closure: nil
            )
        }

        blockTimeService.throttle()
    }

    func startSharedOperation() -> SharedOperationProtocol {
        let operation = SharedOperation()
        sharedOperation = operation
        return operation
    }
}
