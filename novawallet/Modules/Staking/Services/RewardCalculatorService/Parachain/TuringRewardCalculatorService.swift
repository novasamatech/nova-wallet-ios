import Foundation
import RobinHood
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
            logger: logger
        )
    }

    override func didUpdateShapshotParam() {
        if
            let totalIssuance = totalIssuance,
            let totalUnvested = totalUnvested,
            let totalStaked = totalStaked,
            let inflationConfig = inflationConfig,
            let parachainBondConfig = parachainBondConfig {
            let circulating = totalIssuance + totalUnvested

            let snapshot = Snapshot(
                totalStaked: totalStaked,
                totalIssuance: circulating,
                inflation: inflationConfig,
                parachainBond: parachainBondConfig
            )

            updateSnapshotAndNotify(snapshot)
        }
    }

    override func subscribe() {
        super.subscribe()

        subscribeAdditionalIssuance()
    }

    override func unsubscribe() {
        super.unsubscribe()

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
