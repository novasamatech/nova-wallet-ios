import Foundation
import Operation_iOS
import SubstrateSdk
import BigInt

final class TuringRewardCalculatorService: BaseParaStakingRewardCalculatoService {
    let rewardsRemoteSubscriptionService: TuringStakingRemoteSubscriptionProtocol
    let rewardsLocalSubscriptionFactory: TuringStakingLocalSubscriptionFactoryProtocol

    private var rewardsSubscriptionId: UUID?
    private var totalUnvested: BigUInt?
    private var totalUnvestedProvider: AnyDataProvider<DecodedBigUInt>?

    init(
        chainId: ChainModel.Id,
        rewardsRemoteSubscriptionService: TuringStakingRemoteSubscriptionProtocol,
        rewardsLocalSubscriptionFactory: TuringStakingLocalSubscriptionFactoryProtocol,
        collatorsService: ParachainStakingCollatorServiceProtocol,
        providerFactory: ParachainStakingLocalSubscriptionFactoryProtocol,
        connection: JSONRPCEngine,
        runtimeCodingService: RuntimeProviderProtocol,
        repositoryFactory: SubstrateRepositoryFactoryProtocol,
        operationQueue: OperationQueue,
        assetPrecision: Int16,
        eventCenter: EventCenterProtocol,
        logger: LoggerProtocol
    ) {
        self.rewardsRemoteSubscriptionService = rewardsRemoteSubscriptionService
        self.rewardsLocalSubscriptionFactory = rewardsLocalSubscriptionFactory

        super.init(
            chainId: chainId,
            collatorsService: collatorsService,
            providerFactory: providerFactory,
            connection: connection,
            runtimeCodingService: runtimeCodingService,
            repositoryFactory: repositoryFactory,
            operationQueue: operationQueue,
            assetPrecision: assetPrecision,
            eventCenter: eventCenter,
            logger: logger
        )
    }

    override func didUpdateShapshotParam() {
        if
            let totalIssuance,
            let totalUnvested,
            let totalStaked,
            let inflationConfig,
            let inflationDistribution {
            let circulating = totalIssuance + totalUnvested

            let snapshot = ParaStkRewardParamsSnapshot(
                totalStaked: totalStaked,
                totalIssuance: circulating,
                inflation: inflationConfig,
                inflationDistribution: inflationDistribution
            )

            updateSnapshotAndNotify(snapshot, chainId: chainId)
        }
    }

    override func start() {
        super.start()

        subscribeAdditionalIssuance()
    }

    override func stop() {
        super.stop()

        unsubscribeAdditionalIssuance()
    }

    private func subscribeAdditionalIssuance() {
        subscribeAdditionalIssuanceRemote()
        subscribeAdditionalIssuanceLocal()
    }

    private func subscribeAdditionalIssuanceRemote() {
        guard rewardsSubscriptionId == nil else {
            return
        }

        rewardsSubscriptionId = rewardsRemoteSubscriptionService.attachToRewardParameters(
            for: chainId,
            queue: nil,
            closure: nil
        )
    }

    private func subscribeAdditionalIssuanceLocal() {
        guard totalUnvestedProvider == nil else {
            return
        }

        do {
            totalUnvestedProvider = try rewardsLocalSubscriptionFactory.getTotalUnvestedProvider(for: chainId)

            let updateClosure: ([DataProviderChange<DecodedBigUInt>]) -> Void = { [weak self] changes in
                self?.totalUnvested = changes.reduceToLastChange()?.item?.value
                self?.didUpdateShapshotParam()
            }

            let failureClosure: (Error) -> Void = { [weak self] error in
                self?.logger.error("Did receive error: \(error)")
            }

            let options = DataProviderObserverOptions(
                alwaysNotifyOnRefresh: false,
                waitsInProgressSyncOnAdd: false
            )

            totalUnvestedProvider?.addObserver(
                self,
                deliverOn: syncQueue,
                executing: updateClosure,
                failing: failureClosure,
                options: options
            )
        } catch {
            logger.error("Can't make subscription")
        }
    }

    func unsubscribeAdditionalIssuance() {
        unsubscribeAdditionalIssuanceRemote()
        unsubscribeAdditionalIssuanceLocal()
    }

    func unsubscribeAdditionalIssuanceRemote() {
        guard let rewardsSubscriptionId = rewardsSubscriptionId else {
            return
        }

        rewardsRemoteSubscriptionService.detachFromRewardParameters(
            for: rewardsSubscriptionId,
            chainId: chainId,
            queue: nil,
            closure: nil
        )

        self.rewardsSubscriptionId = nil
    }

    func unsubscribeAdditionalIssuanceLocal() {
        totalUnvestedProvider?.removeObserver(self)
        totalUnvestedProvider = nil
    }
}
