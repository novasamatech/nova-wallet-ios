import Foundation
import Operation_iOS

final class SubtensorMaxApyProvider {
    static let defaultMemoLifetime: TimeInterval = 900

    let recommendationService: SubtensorRecommendationServiceProtocol
    let yieldService: SubtensorYieldServiceProtocol
    let operationQueue: OperationQueue
    let memoLifetime: TimeInterval
    let timeProvider: () -> TimeInterval
    let logger: LoggerProtocol

    private let mutex = NSLock()
    private var memo: Memo?

    init(
        recommendationService: SubtensorRecommendationServiceProtocol,
        yieldService: SubtensorYieldServiceProtocol,
        operationQueue: OperationQueue,
        memoLifetime: TimeInterval = SubtensorMaxApyProvider.defaultMemoLifetime,
        timeProvider: @escaping () -> TimeInterval = BittensorMonotonicClock.now,
        logger: LoggerProtocol = Logger.shared
    ) {
        self.recommendationService = recommendationService
        self.yieldService = yieldService
        self.operationQueue = operationQueue
        self.memoLifetime = memoLifetime
        self.timeProvider = timeProvider
        self.logger = logger
    }
}

private extension SubtensorMaxApyProvider {
    struct Memo {
        let maxApy: Decimal?
        let resolvedAt: TimeInterval
    }

    static let recommendedClasses: [SubtensorRecommendationClass] = [.stable, .balanced, .higherUpside]

    func currentMemo() -> Memo? {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        guard let memo, timeProvider() - memo.resolvedAt < memoLifetime else {
            return nil
        }

        return memo
    }

    func memoize(_ maxApy: Decimal?) {
        mutex.lock()

        memo = Memo(maxApy: maxApy, resolvedAt: timeProvider())

        mutex.unlock()
    }

    static func createAlphaYieldsWrapper(
        for netuid: UInt16,
        yieldService: SubtensorYieldServiceProtocol,
        logger: LoggerProtocol
    ) -> CompoundOperationWrapper<SubtensorAlphaYields?> {
        let yieldsWrapper = yieldService.createAlphaYieldsWrapper(for: netuid)

        let optionalOperation = ClosureOperation<SubtensorAlphaYields?> {
            do {
                return try yieldsWrapper.targetOperation.extractNoCancellableResultData()
            } catch {
                logger.warning("Subtensor alpha yields of netuid \(netuid) unavailable for the max APY: \(error)")

                return nil
            }
        }

        optionalOperation.addDependency(yieldsWrapper.targetOperation)

        return yieldsWrapper.insertingTail(operation: optionalOperation)
    }

    static func createBestRateWrapper(
        for pairs: [SubtensorRecommendedPair],
        yieldService: SubtensorYieldServiceProtocol,
        logger: LoggerProtocol
    ) -> CompoundOperationWrapper<Decimal?> {
        let rootNetuid = SubtensorStakingPallet.rootNetuid
        let hasRootPair = pairs.contains { $0.netuid == rootNetuid }
        let rootWrapper = hasRootPair ? yieldService.createRootYieldWrapper() : nil

        let netuids = Set(pairs.map(\.netuid)).subtracting([rootNetuid]).sorted()

        let alphaWrappers = netuids.map { netuid in
            createAlphaYieldsWrapper(for: netuid, yieldService: yieldService, logger: logger)
        }

        let bestRateOperation = ClosureOperation<Decimal?> {
            let rootYield: SubtensorReportedYield? = try rootWrapper?.targetOperation.extractNoCancellableResultData()

            var alphaYields: [UInt16: SubtensorAlphaYields] = [:]

            for (netuid, alphaWrapper) in zip(netuids, alphaWrappers) {
                alphaYields[netuid] = try alphaWrapper.targetOperation.extractNoCancellableResultData()
            }

            return pairs.compactMap { pair in
                guard pair.netuid != rootNetuid else {
                    return rootYield?.annualRate
                }

                return alphaYields[pair.netuid]?.yields[pair.hotkey]?.annualRate
            }.max()
        }

        let dependencies = (rootWrapper?.allOperations ?? []) + alphaWrappers.flatMap(\.allOperations)

        dependencies.forEach { bestRateOperation.addDependency($0) }

        return CompoundOperationWrapper(targetOperation: bestRateOperation, dependencies: dependencies)
    }
}

extension SubtensorMaxApyProvider: SubtensorMaxApyProviderProtocol {
    func createMaxApyWrapper() -> CompoundOperationWrapper<Decimal?> {
        if let memo = currentMemo() {
            return .createWithResult(memo.maxApy)
        }

        let recommendationsWrapper = recommendationService.createVerifiedRecommendationsWrapper()
        let yieldService = yieldService
        let logger = logger

        let bestRateWrapper: CompoundOperationWrapper<Decimal?> =
            OperationCombiningService.compoundNonOptionalWrapper(operationQueue: operationQueue) {
                let recommendations = try recommendationsWrapper.targetOperation.extractNoCancellableResultData()
                let pairs = Self.recommendedClasses.flatMap { recommendations.classes[$0] ?? [] }

                return Self.createBestRateWrapper(for: pairs, yieldService: yieldService, logger: logger)
            }

        bestRateWrapper.addDependency(wrapper: recommendationsWrapper)

        let memoOperation = ClosureOperation<Decimal?> { [weak self] in
            let maxApy = try bestRateWrapper.targetOperation.extractNoCancellableResultData()

            self?.memoize(maxApy)

            return maxApy
        }

        memoOperation.addDependency(bestRateWrapper.targetOperation)

        return bestRateWrapper
            .insertingHead(operations: recommendationsWrapper.allOperations)
            .insertingTail(operation: memoOperation)
    }
}
