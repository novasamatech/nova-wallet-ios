import Foundation
import Operation_iOS

enum SubtensorYieldServiceError: Error {
    case missingYieldPage
}

final class SubtensorYieldService {
    static let alphaYieldPageLimit = 3

    let apiOperationFactory: BittensorApiOperationFactoryProtocol
    let operationQueue: OperationQueue
    let logger: LoggerProtocol

    init(
        apiOperationFactory: BittensorApiOperationFactoryProtocol,
        operationQueue: OperationQueue,
        logger: LoggerProtocol = Logger.shared
    ) {
        self.apiOperationFactory = apiOperationFactory
        self.operationQueue = operationQueue
        self.logger = logger
    }
}

extension SubtensorYieldService {
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
            stamp: aggregateStamp
        )
    }

    static func makeRootYields(
        from result: BittensorApiResult<BittensorApi.RootValidatorCollection>,
        logger: LoggerProtocol
    ) throws -> SubtensorAlphaYields {
        guard let stamp = SubtensorBackendStamp(
            metadata: result.value.meta.components.stakeYieldWindows,
            isFromExpiredCache: result.isFromExpiredCache
        ) else {
            throw SubtensorYieldServiceError.missingYieldPage
        }

        var yields: [AccountId: SubtensorReportedYield] = [:]
        var skippedRows = 0

        for item in result.value.items {
            guard
                let d30 = item.stakeYield.d30,
                let rootStake = item.rootStakeTao.flatMap({ try? BittensorApiDecimal.decimal($0) }),
                rootStake > 0 else {
                continue
            }

            guard let hotkey = try? item.hotkey.toAccountId(
                using: .substrate(SubstrateConstants.genericAddressPrefix)
            ) else {
                skippedRows += 1
                continue
            }

            yields[hotkey] = SubtensorReportedYield(reportedRate: d30.apy, stamp: stamp)
        }

        if skippedRows > 0 {
            logger.warning("Skipped \(skippedRows) root yield rows")
        }

        return SubtensorAlphaYields(netuid: SubtensorStakingPallet.rootNetuid, yields: yields, stamp: stamp)
    }

    static func makeNetworkRootRate(
        from result: BittensorApiResult<BittensorApi.RootOverview>
    ) -> SubtensorReportedYield? {
        guard
            let rate = result.value.validatorYield?.stakeWeightedApy24h,
            let stamp = SubtensorBackendStamp(
                metadata: result.value.meta.components.validatorYield,
                isFromExpiredCache: result.isFromExpiredCache
            ) else {
            return nil
        }

        return SubtensorReportedYield(reportedRate: rate, stamp: stamp)
    }
}

extension SubtensorYieldService: SubtensorYieldServiceProtocol {
    func createAlphaYieldsWrapper(for netuid: UInt16) -> CompoundOperationWrapper<SubtensorAlphaYields> {
        let logger = logger

        guard netuid != SubtensorStakingPallet.rootNetuid else {
            let rootWrapper = apiOperationFactory.createRootValidatorsWrapper()

            let mappingOperation = ClosureOperation<SubtensorAlphaYields> {
                let result = try rootWrapper.targetOperation.extractNoCancellableResultData()

                return try Self.makeRootYields(from: result, logger: logger)
            }

            mappingOperation.addDependency(rootWrapper.targetOperation)

            return rootWrapper.insertingTail(operation: mappingOperation)
        }

        let apiOperationFactory = apiOperationFactory

        let pagesWrapper = BittensorApiPagination.createPagesWrapper(
            maxPages: Self.alphaYieldPageLimit,
            operationQueue: operationQueue,
            nextPage: { $0.pageInfo.nextPage },
            pageWrapper: { page in
                apiOperationFactory.createAlphaYieldWrapper(netuid: netuid, page: page)
            }
        )

        let mappingOperation = ClosureOperation<SubtensorAlphaYields> {
            let pages = try pagesWrapper.targetOperation.extractNoCancellableResultData()

            return try Self.makeAlphaYields(netuid: netuid, pages: pages, logger: logger)
        }

        mappingOperation.addDependency(pagesWrapper.targetOperation)

        return pagesWrapper.insertingTail(operation: mappingOperation)
    }

    func cachedAlphaYields(for netuid: UInt16) -> HTTPCachePeek<SubtensorAlphaYields> {
        guard netuid != SubtensorStakingPallet.rootNetuid else {
            return apiOperationFactory.peekRootValidators().map { try Self.makeRootYields(from: $0, logger: logger) }
        }

        let pagesPeek = BittensorApiPagination.peekPages(
            maxPages: Self.alphaYieldPageLimit,
            nextPage: { $0.pageInfo.nextPage },
            peekPage: { page in
                apiOperationFactory.peekAlphaYield(netuid: netuid, page: page)
            }
        )

        return pagesPeek.map { try Self.makeAlphaYields(netuid: netuid, pages: $0, logger: logger) }
    }

    func createNetworkRootRateWrapper() -> CompoundOperationWrapper<SubtensorReportedYield?> {
        let overviewWrapper = apiOperationFactory.createRootOverviewWrapper()

        let mappingOperation = ClosureOperation<SubtensorReportedYield?> {
            let result = try overviewWrapper.targetOperation.extractNoCancellableResultData()

            return Self.makeNetworkRootRate(from: result)
        }

        mappingOperation.addDependency(overviewWrapper.targetOperation)

        return overviewWrapper.insertingTail(operation: mappingOperation)
    }
}
