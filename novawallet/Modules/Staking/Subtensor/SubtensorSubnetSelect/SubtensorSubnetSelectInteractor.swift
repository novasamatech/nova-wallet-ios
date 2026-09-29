import Foundation
import Operation_iOS
import SubstrateSdk

final class SubtensorSubnetSelectInteractor: RuntimeConstantFetching {
    weak var presenter: SubnetSelectInteractorOutputProtocol?

    let subnetsService: SubtensorSubnetsServiceProtocol
    let priceHistoryService: SubtensorPriceHistoryServiceProtocol?
    let runtimeProvider: RuntimeCodingServiceProtocol
    let operationQueue: OperationQueue
    let logger: LoggerProtocol

    init(
        subnetsService: SubtensorSubnetsServiceProtocol,
        priceHistoryService: SubtensorPriceHistoryServiceProtocol?,
        runtimeProvider: RuntimeCodingServiceProtocol,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.subnetsService = subnetsService
        self.priceHistoryService = priceHistoryService
        self.runtimeProvider = runtimeProvider
        self.operationQueue = operationQueue
        self.logger = logger
    }
}

private extension SubtensorSubnetSelectInteractor {
    func provideSubnetsInfo() {
        subnetsService.fetchSubnetsInfo(runningCompletionIn: .main) { [weak self] result in
            switch result {
            case let .success(info):
                self?.presenter?.didReceiveSubnetsInfo(info)
                self?.provideWeeklyChanges(for: info)
            case let .failure(error):
                self?.presenter?.didReceiveError(error)
            }
        }
    }

    func provideWeeklyChanges(for info: SubtensorSubnetsInfo) {
        guard let priceHistoryService else {
            presenter?.didReceiveWeeklyChanges([:])
            return
        }

        let subnets = info.subnets
            .filter { info.subtokenEnabled.contains($0.netuid) }
            .map { SubtensorSubnetRef(netuid: $0.netuid, registeredAt: $0.networkRegisteredAt) }
        let wrapper = priceHistoryService.createWeeklyChangesWrapper(for: subnets)

        execute(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(prices):
                self?.presenter?.didReceiveWeeklyChanges(prices.compactMapValues { $0.availableValue?.change })
            case let .failure(error):
                self?.logger.warning("Subnet weekly changes unavailable: \(error)")
                self?.presenter?.didReceiveWeeklyChanges([:])
            }
        }
    }

    func provideDefaultTake() {
        fetchConstant(
            for: SubtensorStakingPallet.initialDefaultDelegateTakePath,
            runtimeCodingService: runtimeProvider,
            operationQueue: operationQueue
        ) { [weak self] (result: Result<UInt16, Error>) in
            switch result {
            case let .success(take):
                self?.presenter?.didReceiveDefaultTake(take)
            case let .failure(error):
                self?.logger.error("Default take fetch failed: \(error)")
            }
        }
    }

    func handleMonthlyMetrics(_ metrics: [SubtensorSubnetRef: SubtensorPriceData<SubtensorMonthlyPriceMetrics>]) {
        let values = metrics.values

        guard !values.contains(where: { $0.availableValue != nil }), values.contains(.unavailable) else {
            presenter?.didReceiveMonthlyMetrics(metrics)
            return
        }

        presenter?.didFailMonthlyMetrics()
    }
}

extension SubtensorSubnetSelectInteractor: SubnetSelectInteractorInputProtocol {
    func loadMonthlyMetrics(for info: SubtensorSubnetsInfo) {
        guard let priceHistoryService else {
            presenter?.didFailMonthlyMetrics()
            return
        }
        let subnets = info.subnets
            .filter { info.subtokenEnabled.contains($0.netuid) }
            .map { SubtensorSubnetRef(netuid: $0.netuid, registeredAt: $0.networkRegisteredAt) }
        let wrapper = priceHistoryService.createMonthlyMetricsWrapper(for: subnets)
        execute(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(metrics): self?.handleMonthlyMetrics(metrics)
            case let .failure(error):
                self?.logger.warning("Subnet monthly metrics unavailable: \(error)")
                self?.presenter?.didFailMonthlyMetrics()
            }
        }
    }

    func setup() {
        provideDefaultTake()
        provideSubnetsInfo()
    }

    func refresh() {
        provideSubnetsInfo()
    }
}
