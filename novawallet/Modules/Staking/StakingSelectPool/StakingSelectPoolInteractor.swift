import UIKit
import SubstrateSdk
import RobinHood

final class StakingSelectPoolInteractor: AnyCancellableCleaning, AnyProviderAutoCleaning {
    weak var presenter: StakingSelectPoolInteractorOutputProtocol?
    let poolsOperationFactory: NominationPoolsOperationFactoryProtocol
    let eraPoolsService: EraNominationPoolsServiceProtocol
    let validatorRewardService: RewardCalculatorServiceProtocol
    let connection: JSONRPCEngine
    let runtimeService: RuntimeCodingServiceProtocol
    let npoolsLocalSubscriptionFactory: NPoolsLocalSubscriptionFactoryProtocol
    let chainAsset: ChainAsset
    let rewardEngineOperationFactory: NPoolsRewardEngineFactoryProtocol

    private var maxMembersPerPoolProvider: AnyDataProvider<DecodedU32>?
    private var maxPoolMembersPerPool: UncertainStorage<UInt32?> = .undefined
    private var poolsCancellable: CancellableCall?

    private let operationQueue: OperationQueue

    init(
        poolsOperationFactory: NominationPoolsOperationFactoryProtocol,
        npoolsLocalSubscriptionFactory: NPoolsLocalSubscriptionFactoryProtocol,
        rewardEngineOperationFactory: NPoolsRewardEngineFactoryProtocol,
        eraPoolsService: EraNominationPoolsServiceProtocol,
        validatorRewardService: RewardCalculatorServiceProtocol,
        connection: JSONRPCEngine,
        runtimeService: RuntimeCodingServiceProtocol,
        chainAsset: ChainAsset,
        operationQueue: OperationQueue
    ) {
        self.poolsOperationFactory = poolsOperationFactory
        self.npoolsLocalSubscriptionFactory = npoolsLocalSubscriptionFactory
        self.rewardEngineOperationFactory = rewardEngineOperationFactory
        self.eraPoolsService = eraPoolsService
        self.validatorRewardService = validatorRewardService
        self.connection = connection
        self.runtimeService = runtimeService
        self.chainAsset = chainAsset
        self.operationQueue = operationQueue
    }

    deinit {
        clear(dataProvider: &maxMembersPerPoolProvider)
    }

    private func performMaxMembersPerPoolSubscription() {
        maxMembersPerPoolProvider = subscribeMaxPoolMembersPerPool(for: chainAsset.chain.chainId)
    }

    private func fetchSparePoolsInfo() {
        clear(cancellable: &poolsCancellable)

        let maxApyWrapper = rewardEngineOperationFactory.createEngineWrapper(
            for: eraPoolsService,
            validatorRewardService: validatorRewardService,
            connection: connection,
            runtimeService: runtimeService
        )

        let poolStatsWrapper = poolsOperationFactory.createSparePoolsInfoWrapper(
            for: eraPoolsService,
            rewardEngine: {
                try maxApyWrapper.targetOperation.extractNoCancellableResultData()
            },
            maxMembersPerPool: { self.maxPoolMembersPerPool.value ?? nil },
            connection: connection,
            runtimeService: runtimeService
        )
        poolStatsWrapper.addDependency(wrapper: maxApyWrapper)

        poolStatsWrapper.targetOperation.completionBlock = { [weak self] in
            guard poolStatsWrapper === self?.poolsCancellable else {
                return
            }
            self?.poolsCancellable = nil

            DispatchQueue.main.async {
                do {
                    let stats = try poolStatsWrapper.targetOperation.extractNoCancellableResultData()
                    self?.presenter?.didReceive(poolStats: stats)
                } catch {
                    // TODO:
                }
            }
        }

        poolsCancellable = poolStatsWrapper
        operationQueue.addOperations(
            maxApyWrapper.allOperations + poolStatsWrapper.allOperations,
            waitUntilFinished: false
        )
    }
}

extension StakingSelectPoolInteractor: StakingSelectPoolInteractorInputProtocol {
    func setup() {
        performMaxMembersPerPoolSubscription()
    }

    func refreshPools() {
        guard maxPoolMembersPerPool.isDefined else {
            return
        }
        fetchSparePoolsInfo()
    }
}

extension StakingSelectPoolInteractor: NPoolsLocalStorageSubscriber, NPoolsLocalSubscriptionHandler {
    func handleMaxPoolMembersPerPool(result: Result<UInt32?, Error>, chainId _: ChainModel.Id) {
        switch result {
        case let .success(value):
            maxPoolMembersPerPool = .defined(value)
            fetchSparePoolsInfo()
        case let .failure(error):
            break
            // TODO:
        }
    }
}
