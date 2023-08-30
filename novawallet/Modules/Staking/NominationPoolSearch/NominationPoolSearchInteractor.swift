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
    let searchOperationFactory: NominationPoolSearchOperationFactoryProtocol

    private var lastPoolIdProvider: AnyDataProvider<DecodedPoolId>?
    private var lastPoolId: NominationPools.PoolId?
    private var currentSearchOperation: CancellableCall?
    private var searchOperationClosure: NominationPoolSearchOperationClosure?

    private var poolsCancellable: CancellableCall?
    private let operationQueue: OperationQueue
    private lazy var operationManager = OperationManager(operationQueue: operationQueue)

    private var currentSearchText: String?

    init(
        chainAsset: ChainAsset,
        poolsOperationFactory: NominationPoolsOperationFactoryProtocol,
        npoolsLocalSubscriptionFactory: NPoolsLocalSubscriptionFactoryProtocol,
        rewardEngineOperationFactory: NPoolsRewardEngineFactoryProtocol,
        eraNominationPoolsService: EraNominationPoolsServiceProtocol,
        validatorRewardService: RewardCalculatorServiceProtocol,
        connection: JSONRPCEngine,
        runtimeService: RuntimeCodingServiceProtocol,
        searchOperationFactory: NominationPoolSearchOperationFactoryProtocol,
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
        self.searchOperationFactory = searchOperationFactory
        self.operationQueue = operationQueue
    }

    deinit {
        clear(cancellable: &poolsCancellable)
        clear(cancellable: &currentSearchOperation)
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

        let poolStatsWrapper: CompoundOperationWrapper<[NominationPools.PoolStats]?> =
            OperationCombiningService.compoundWrapper(operationManager: operationManager) { [weak self] in
                guard let self = self else {
                    return nil
                }
                let maxApy = try maxApyWrapper.targetOperation.extractNoCancellableResultData()

                return self.poolsOperationFactory.createAllPoolsInfoWrapper(
                    rewardEngine: { maxApy },
                    lastPoolId: lastPoolId,
                    connection: self.connection,
                    runtimeService: self.runtimeService
                )
            }

        poolStatsWrapper.addDependency(wrapper: maxApyWrapper)

        poolStatsWrapper.targetOperation.completionBlock = { [weak self] in
            guard poolStatsWrapper === self?.poolsCancellable else {
                return
            }
            self?.poolsCancellable = nil

            DispatchQueue.main.async {
                do {
                    let stats = try poolStatsWrapper.targetOperation.extractNoCancellableResultData() ?? []
                    self?.searchOperationClosure = self?.searchOperationFactory.createOperationClosure(stats: stats)
                    self?.performSearchIfNeeded()
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

    private func performSearchIfNeeded() {
        guard let text = currentSearchText, let searchOperationClosure = searchOperationClosure else {
            return
        }

        if text.isEmpty {
            presenter?.didReceive(poolStats: [])
        } else {
            clear(cancellable: &currentSearchOperation)
            let searchOperation = searchOperationClosure(text)
            searchOperation.completionBlock = { [weak self] in
                DispatchQueue.main.async {
                    guard self?.currentSearchOperation === searchOperation else {
                        return
                    }

                    self?.currentSearchOperation = nil

                    let result = (try? searchOperation.extractNoCancellableResultData()) ?? []

                    if !result.isEmpty {
                        self?.presenter?.didReceive(poolStats: result)
                    } else {
                        self?.presenter?.didReceive(error: .emptySearchResults)
                    }
                }
            }

            currentSearchOperation = searchOperation
            operationQueue.addOperation(searchOperation)
        }
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

    func search(for text: String) {
        currentSearchText = text

        guard searchOperationClosure != nil else {
            presenter?.didStartSearch(for: text)
            return
        }

        performSearchIfNeeded()
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
