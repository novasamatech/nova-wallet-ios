import Foundation
import Operation_iOS

final class SubtensorMaxApyProvider {
    static let defaultRequestSpacing: TimeInterval = 20
    static let defaultRetryDelay: TimeInterval = 60

    let recommendationService: SubtensorRecommendationServiceProtocol
    let apiOperationFactory: BittensorApiOperationFactoryProtocol
    let resolution: SubtensorMaxApyResolution
    let operationQueue: OperationQueue
    let requestSpacing: TimeInterval
    let retryDelay: TimeInterval
    let timeProvider: () -> TimeInterval
    let logger: LoggerProtocol

    init(
        recommendationService: SubtensorRecommendationServiceProtocol,
        apiOperationFactory: BittensorApiOperationFactoryProtocol,
        resolution: SubtensorMaxApyResolution,
        operationQueue: OperationQueue,
        requestSpacing: TimeInterval = SubtensorMaxApyProvider.defaultRequestSpacing,
        retryDelay: TimeInterval = SubtensorMaxApyProvider.defaultRetryDelay,
        timeProvider: @escaping () -> TimeInterval = BittensorMonotonicClock.now,
        logger: LoggerProtocol = Logger.shared
    ) {
        self.recommendationService = recommendationService
        self.apiOperationFactory = apiOperationFactory
        self.resolution = resolution
        self.operationQueue = operationQueue
        self.requestSpacing = requestSpacing
        self.retryDelay = retryDelay
        self.timeProvider = timeProvider
        self.logger = logger
    }
}

private extension SubtensorMaxApyProvider {
    func startWalk(completion: @escaping SubtensorMaxApyResolution.Completion) -> CancellableCall {
        let walk = SubtensorMaxApyWalk(
            recommendationService: recommendationService,
            apiOperationFactory: apiOperationFactory,
            operationQueue: operationQueue,
            requestSpacing: requestSpacing,
            retryDelay: retryDelay,
            timeProvider: timeProvider,
            logger: logger
        )

        walk.start(completion: completion)

        return walk
    }
}

extension SubtensorMaxApyProvider: SubtensorMaxApyProviderProtocol {
    func createMaxApyWrapper() -> CompoundOperationWrapper<Decimal?> {
        let waiterId = UUID()
        let resolution = resolution

        let operation = AsyncClosureOperation<Decimal?>(
            operationClosure: { [self] completion in
                resolution.resolve(for: waiterId, startingWalkWith: startWalk, completion: completion)
            },
            cancelationClosure: {
                resolution.leave(waiterId)
            }
        )

        return CompoundOperationWrapper(targetOperation: operation)
    }
}
