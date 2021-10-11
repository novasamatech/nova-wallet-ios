import UIKit
import RobinHood

final class StakingRewardPayoutsInteractor {
    weak var presenter: StakingRewardPayoutsInteractorOutputProtocol!

    let stakingLocalSubscriptionFactory: StakingLocalSubscriptionFactoryProtocol
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol

    private let payoutService: PayoutRewardsServiceProtocol
    private let chainRegistry: ChainRegistryProtocol
    private let chainAsset: ChainAsset
    private let eraCountdownOperationFactory: EraCountdownOperationFactoryProtocol
    private let operationManager: OperationManagerProtocol
    private let logger: LoggerProtocol?

    private var priceProvider: AnySingleValueProvider<PriceData>?
    private var activeEraProvider: AnyDataProvider<DecodedActiveEra>?
    private var payoutOperationsWrapper: CompoundOperationWrapper<PayoutsInfo>?

    deinit {
        let wrapper = payoutOperationsWrapper
        payoutOperationsWrapper = nil
        wrapper?.cancel()
    }

    init(
        chainAsset: ChainAsset,
        chainRegistry: ChainRegistryProtocol,
        stakingLocalSubscriptionFactory: StakingLocalSubscriptionFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        payoutService: PayoutRewardsServiceProtocol,
        eraCountdownOperationFactory: EraCountdownOperationFactoryProtocol,
        operationManager: OperationManagerProtocol,
        logger: LoggerProtocol? = nil
    ) {
        self.chainAsset = chainAsset
        self.chainRegistry = chainRegistry
        self.stakingLocalSubscriptionFactory = stakingLocalSubscriptionFactory
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.payoutService = payoutService
        self.eraCountdownOperationFactory = eraCountdownOperationFactory
        self.operationManager = operationManager
        self.logger = logger
    }

    private func fetchEraCompletionTime() {
        guard let connection = chainRegistry.getConnection(for: chainAsset.chain.chainId) else {
            presenter.didReceive(eraCountdownResult: .failure(ChainRegistryError.connectionUnavailable))
            return
        }

        guard let runtimeService = chainRegistry.getRuntimeProvider(for: chainAsset.chain.chainId) else {
            presenter.didReceive(eraCountdownResult: .failure(ChainRegistryError.runtimeMetadaUnavailable))
            return
        }

        let operationWrapper = eraCountdownOperationFactory.fetchCountdownOperationWrapper(
            for: connection,
            runtimeService: runtimeService
        )

        operationWrapper.targetOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                do {
                    let result = try operationWrapper.targetOperation.extractNoCancellableResultData()
                    self?.presenter.didReceive(eraCountdownResult: .success(result))
                } catch {
                    self?.presenter.didReceive(eraCountdownResult: .failure(error))
                }
            }
        }
        operationManager.enqueue(operations: operationWrapper.allOperations, in: .transient)
    }
}

extension StakingRewardPayoutsInteractor: StakingRewardPayoutsInteractorInputProtocol {
    func setup() {
        if let priceId = chainAsset.asset.priceId {
            priceProvider = subscribeToPrice(for: priceId)
        } else {
            presenter.didReceive(priceResult: .success(nil))
        }

        activeEraProvider = subscribeActiveEra(for: chainAsset.chain.chainId)

        fetchEraCompletionTime()
        reload()
    }

    func reload() {
        guard payoutOperationsWrapper == nil else {
            return
        }

        let wrapper = payoutService.fetchPayoutsOperationWrapper()
        wrapper.targetOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                do {
                    guard let currentWrapper = self?.payoutOperationsWrapper else {
                        return
                    }

                    self?.payoutOperationsWrapper = nil

                    let payoutsInfo = try currentWrapper.targetOperation.extractNoCancellableResultData()
                    self?.presenter?.didReceive(result: .success(payoutsInfo))
                } catch {
                    if let serviceError = error as? PayoutRewardsServiceError {
                        self?.presenter.didReceive(result: .failure(serviceError))
                    } else {
                        self?.presenter.didReceive(result: .failure(.unknown))
                    }
                }
            }
        }

        operationManager.enqueue(operations: wrapper.allOperations, in: .transient)

        payoutOperationsWrapper = wrapper
    }
}

extension StakingRewardPayoutsInteractor: StakingLocalStorageSubscriber, StakingLocalSubscriptionHandler {
    func handleActiveEra(result: Result<ActiveEraInfo?, Error>, chainId _: ChainModel.Id) {
        switch result {
        case .success:
            reload()
            fetchEraCompletionTime()
        case let .failure(error):
            logger?.error(error.localizedDescription)
        }
    }
}

extension StakingRewardPayoutsInteractor: PriceLocalStorageSubscriber, PriceLocalSubscriptionHandler {
    func handlePrice(result: Result<PriceData?, Error>, priceId _: AssetModel.PriceId) {
        switch result {
        case let .success(priceData):
            presenter.didReceive(priceResult: .success(priceData))
        case let .failure(error):
            presenter.didReceive(priceResult: .failure(error))
        }
    }
}
