import UIKit
import SubstrateSdk
import RobinHood
import BigInt

final class StakingSelectPoolInteractor: AnyCancellableCleaning, AnyProviderAutoCleaning {
    weak var presenter: StakingSelectPoolInteractorOutputProtocol?
    let poolsOperationFactory: NominationPoolsOperationFactoryProtocol
    let eraNominationPoolsService: EraNominationPoolsServiceProtocol
    let validatorRewardService: RewardCalculatorServiceProtocol
    let connection: JSONRPCEngine
    let runtimeService: RuntimeCodingServiceProtocol
    let npoolsLocalSubscriptionFactory: NPoolsLocalSubscriptionFactoryProtocol
    let chainAsset: ChainAsset
    let rewardEngineOperationFactory: NPoolsRewardEngineFactoryProtocol
    let recommendationMediator: RelaychainStakingRecommendationMediating
    let amount: BigUInt

    private var maxMembersPerPoolProvider: AnyDataProvider<DecodedU32>?
    private var maxPoolMembersPerPool: UncertainStorage<UInt32?> = .undefined
    private var poolsCancellable: CancellableCall?

    private let operationQueue: OperationQueue

    init(
        poolsOperationFactory: NominationPoolsOperationFactoryProtocol,
        npoolsLocalSubscriptionFactory: NPoolsLocalSubscriptionFactoryProtocol,
        rewardEngineOperationFactory: NPoolsRewardEngineFactoryProtocol,
        recommendationMediator: RelaychainStakingRecommendationMediating,
        eraNominationPoolsService: EraNominationPoolsServiceProtocol,
        validatorRewardService: RewardCalculatorServiceProtocol,
        connection: JSONRPCEngine,
        runtimeService: RuntimeCodingServiceProtocol,
        chainAsset: ChainAsset,
        amount: BigUInt,
        operationQueue: OperationQueue
    ) {
        self.poolsOperationFactory = poolsOperationFactory
        self.npoolsLocalSubscriptionFactory = npoolsLocalSubscriptionFactory
        self.rewardEngineOperationFactory = rewardEngineOperationFactory
        self.recommendationMediator = recommendationMediator
        self.eraNominationPoolsService = eraNominationPoolsService
        self.validatorRewardService = validatorRewardService
        self.connection = connection
        self.runtimeService = runtimeService
        self.chainAsset = chainAsset
        self.amount = amount
        self.operationQueue = operationQueue
    }

    private func performMaxMembersPerPoolSubscription() {
        clear(dataProvider: &maxMembersPerPoolProvider)
        maxMembersPerPoolProvider = subscribeMaxPoolMembersPerPool(for: chainAsset.chain.chainId)
    }

    private func fetchSparePoolsInfo() {
        clear(cancellable: &poolsCancellable)

        let maxApyWrapper = rewardEngineOperationFactory.createEngineWrapper(
            for: eraNominationPoolsService,
            validatorRewardService: validatorRewardService,
            connection: connection,
            runtimeService: runtimeService
        )

        let maxPoolMembers = maxPoolMembersPerPool.value ?? nil
        let preferrablePool = StakingConstants.recommendedPoolIds[chainAsset.chain.chainId]
        let params = RecommendedNominationPoolsParams(
            maxMembersPerPool: { maxPoolMembers },
            preferrablePool: { preferrablePool }
        )

        let poolStatsWrapper = poolsOperationFactory.createPoolRecommendationsInfoWrapper(
            for: eraNominationPoolsService,
            rewardEngine: {
                try maxApyWrapper.targetOperation.extractNoCancellableResultData()
            },
            params: params,
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
                    self?.presenter?.didReceive(error: .poolStats(error))
                }
            }
        }

        poolsCancellable = poolStatsWrapper
        operationQueue.addOperations(
            maxApyWrapper.allOperations + poolStatsWrapper.allOperations,
            waitUntilFinished: false
        )
    }

    private func provideRecommendation() {
        recommendationMediator.delegate = self
        recommendationMediator.startRecommending()
        recommendationMediator.update(amount: amount)
    }
}

extension StakingSelectPoolInteractor: StakingSelectPoolInteractorInputProtocol {
    func setup() {
        performMaxMembersPerPoolSubscription()
        provideRecommendation()
    }

    func refreshPools() {
        guard maxPoolMembersPerPool.isDefined else {
            performMaxMembersPerPoolSubscription()
            return
        }
        fetchSparePoolsInfo()
    }

    func refreshRecommendation() {
        provideRecommendation()
    }
}

extension StakingSelectPoolInteractor: NPoolsLocalStorageSubscriber, NPoolsLocalSubscriptionHandler {
    func handleMaxPoolMembersPerPool(result: Result<UInt32?, Error>, chainId _: ChainModel.Id) {
        switch result {
        case let .success(value):
            maxPoolMembersPerPool = .defined(value)
            fetchSparePoolsInfo()
        case let .failure(error):
            presenter?.didReceive(error: .poolStats(error))
        }
    }
}

extension StakingSelectPoolInteractor: RelaychainStakingRecommendationDelegate {
    func didReceive(
        recommendation: RelaychainStakingRecommendation,
        amount _: BigUInt
    ) {
        guard case let .pool(recommendedPool) = recommendation.staking else {
            return
        }
        presenter?.didReceive(recommendedPool: recommendedPool)
    }

    func didReceiveRecommendation(error: Error) {
        presenter?.didReceive(error: .recommendation(error))
    }
}
