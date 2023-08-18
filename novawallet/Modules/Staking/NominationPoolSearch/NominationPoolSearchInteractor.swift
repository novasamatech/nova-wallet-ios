import UIKit
import SubstrateSdk
import RobinHood

final class NominationPoolSearchInteractor: AnyCancellableCleaning, AnyProviderAutoCleaning {
    weak var presenter: NominationPoolSearchInteractorOutputProtocol?

    let poolsOperationFactory: NominationPoolsOperationFactoryProtocol
    let eraNominationPoolsService: EraNominationPoolsServiceProtocol
    let validatorRewardService: RewardCalculatorServiceProtocol
    let connection: JSONRPCEngine
    let runtimeService: RuntimeCodingServiceProtocol
    let npoolsLocalSubscriptionFactory: NPoolsLocalSubscriptionFactoryProtocol
    let rewardEngineOperationFactory: NPoolsRewardEngineFactoryProtocol
    let chainAsset: ChainAsset

    private var lastPoolIdProvider: AnyDataProvider<DecodedPoolId>?
    private var lastPoolId: NominationPools.PoolId?

    private var poolsCancellable: CancellableCall?
    private let operationQueue: OperationQueue

    init(
        chainAsset: ChainAsset,
        poolsOperationFactory: NominationPoolsOperationFactoryProtocol,
        npoolsLocalSubscriptionFactory: NPoolsLocalSubscriptionFactoryProtocol,
        rewardEngineOperationFactory: NPoolsRewardEngineFactoryProtocol,
        eraNominationPoolsService: EraNominationPoolsServiceProtocol,
        validatorRewardService: RewardCalculatorServiceProtocol,
        connection: JSONRPCEngine,
        runtimeService: RuntimeCodingServiceProtocol,
        operationQueue: OperationQueue
    ) {
        self.chainAsset = chainAsset
        self.poolsOperationFactory = poolsOperationFactory
        self.npoolsLocalSubscriptionFactory = npoolsLocalSubscriptionFactory
        self.rewardEngineOperationFactory = rewardEngineOperationFactory
        self.eraNominationPoolsService = eraNominationPoolsService
        self.validatorRewardService = validatorRewardService
        self.connection = connection
        self.runtimeService = runtimeService
        self.operationQueue = operationQueue
    }

    private func performLastPoolIdSubscription() {
        clear(dataProvider: &lastPoolIdProvider)
        lastPoolIdProvider = subscribeLastPoolId(for: chainAsset.chain.chainId)
    }

    private func fetchAllPoolsInfo() {
        guard let lastPoolId = lastPoolId else {
            return
        }
        clear(cancellable: &poolsCancellable)

        let maxApyWrapper = rewardEngineOperationFactory.createEngineWrapper(
            for: eraNominationPoolsService,
            validatorRewardService: validatorRewardService,
            connection: connection,
            runtimeService: runtimeService
        )

        let poolStatsWrapper = poolsOperationFactory.createAllPoolsInfoWrapper(
            rewardEngine: {
                try maxApyWrapper.targetOperation.extractNoCancellableResultData()
            },
            lastPoolId: lastPoolId,
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
                    self?.presenter?.didReceive(error: .pools(error))
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

extension NominationPoolSearchInteractor: NominationPoolSearchInteractorInputProtocol {
    func setup() {
        performLastPoolIdSubscription()
        fetchAllPoolsInfo()
    }

    func refetchPools() {
        fetchAllPoolsInfo()
    }

    func remakeSubscriptions() {
        performLastPoolIdSubscription()
    }
}

extension NominationPoolSearchInteractor: NPoolsLocalStorageSubscriber, NPoolsLocalSubscriptionHandler {
    func handleLastPoolId(result: Result<NominationPools.PoolId?, Error>, chainId _: ChainModel.Id) {
        switch result {
        case let .success(value):
            lastPoolId = value
            fetchAllPoolsInfo()
        case let .failure(error):
            presenter?.didReceive(error: .pools(error))
        }
    }
}
