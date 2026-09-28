import Foundation
import Operation_iOS

enum SubtensorYieldServiceError: Error {
    case missingYieldPage
}

final class SubtensorYieldService {
    static let alphaYieldPageLimit = 3

    let apiOperationFactory: BittensorApiOperationFactoryProtocol
    let rewardCalculatorService: SubtensorRewardCalculatorServiceProtocol
    let operationQueue: OperationQueue
    let logger: LoggerProtocol

    private let callbackQueue = DispatchQueue(label: "com.novawallet.subtensor.yields.\(UUID().uuidString)")

    init(
        apiOperationFactory: BittensorApiOperationFactoryProtocol,
        rewardCalculatorService: SubtensorRewardCalculatorServiceProtocol,
        operationQueue: OperationQueue,
        logger: LoggerProtocol = Logger.shared
    ) {
        self.apiOperationFactory = apiOperationFactory
        self.rewardCalculatorService = rewardCalculatorService
        self.operationQueue = operationQueue
        self.logger = logger
    }
}

private extension SubtensorYieldService {
    static func perU16Take(fromFraction take: Decimal) -> UInt16? {
        guard take >= 0, take <= 1 else {
            return nil
        }

        var scaled = take * Decimal(SubtensorStakingPallet.perU16Denominator)
        var rounded = Decimal()
        NSDecimalRound(&rounded, &scaled, 0, .plain)

        return NSDecimalNumber(decimal: rounded).uint16Value
    }

    static func rootRate(engine: SubtensorRewardCalculatorEngineProtocol, take: Decimal?) -> SubtensorRate? {
        guard let take else {
            return engine.rootAnnualReturn().map {
                SubtensorRate(annualRate: $0, source: .chainNetworkAverage(isNetOfTake: false))
            }
        }

        guard let perU16Take = perU16Take(fromFraction: take) else {
            return nil
        }

        return engine.rootAnnualReturn(take: perU16Take).map {
            SubtensorRate(annualRate: $0, source: .chainNetworkAverage(isNetOfTake: true))
        }
    }

    static func makeAlphaYields(
        netuid: UInt16,
        pages: BittensorApiPages<BittensorApi.AlphaYieldCollection>,
        logger: LoggerProtocol
    ) throws -> SubtensorAlphaYields {
        let pageStamps = pages.pages.map { page in
            SubtensorBackendStamp(
                component: page.value.meta.components.alphaYield,
                isFromExpiredCache: page.isFromExpiredCache
            )
        }

        guard let aggregateStamp = SubtensorBackendStamp.aggregate(pageStamps) else {
            throw SubtensorYieldServiceError.missingYieldPage
        }

        var yields: [AccountId: SubtensorReportedYield] = [:]
        var skippedRows = 0

        for (page, pageStamp) in zip(pages.pages, pageStamps) {
            for item in page.value.items {
                guard
                    item.netuid == netuid,
                    let hotkey = try? item.hotkey.toAccountId(
                        using: .substrate(SubstrateConstants.genericAddressPrefix)
                    ) else {
                    skippedRows += 1
                    continue
                }

                if yields[hotkey] == nil {
                    yields[hotkey] = SubtensorReportedYield(reportedRate: item.reportedRate, stamp: pageStamp)
                }
            }
        }

        if skippedRows > 0 {
            logger.warning("Skipped \(skippedRows) alpha yield rows of netuid \(netuid)")
        }

        return SubtensorAlphaYields(
            netuid: netuid,
            yields: yields,
            stamp: aggregateStamp,
            isTruncated: pages.hasMorePages
        )
    }
}

extension SubtensorYieldService: SubtensorYieldServiceProtocol {
    func createAlphaYieldsWrapper(for netuid: UInt16) -> CompoundOperationWrapper<SubtensorAlphaYields> {
        let apiOperationFactory = apiOperationFactory

        let pagesWrapper = BittensorApiPagination.createPagesWrapper(
            maxPages: Self.alphaYieldPageLimit,
            operationQueue: operationQueue,
            nextPage: { $0.pageInfo.nextPage },
            pageWrapper: { page in
                apiOperationFactory.createAlphaYieldWrapper(netuid: netuid, page: page)
            }
        )

        let logger = logger

        let mappingOperation = ClosureOperation<SubtensorAlphaYields> {
            let pages = try pagesWrapper.targetOperation.extractNoCancellableResultData()

            return try Self.makeAlphaYields(netuid: netuid, pages: pages, logger: logger)
        }

        mappingOperation.addDependency(pagesWrapper.targetOperation)

        return pagesWrapper.insertingTail(operation: mappingOperation)
    }

    func createRootNetworkRateWrapper(take: Decimal?) -> CompoundOperationWrapper<SubtensorRate?> {
        let rewardCalculatorService = rewardCalculatorService
        let callbackQueue = callbackQueue
        let logger = logger

        let rateOperation = AsyncClosureOperation<SubtensorRate?> { completion in
            rewardCalculatorService.fetchEngine(runningCompletionIn: callbackQueue) { result in
                switch result {
                case let .success(engine):
                    completion(.success(Self.rootRate(engine: engine, take: take)))
                case let .failure(error):
                    logger.warning("Root network rate unavailable: \(error)")
                    completion(.success(nil))
                }
            }
        }

        return CompoundOperationWrapper(targetOperation: rateOperation)
    }
}
