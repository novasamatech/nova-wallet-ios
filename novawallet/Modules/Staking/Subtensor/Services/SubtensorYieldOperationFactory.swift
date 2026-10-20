import Foundation
import Operation_iOS

enum SubtensorYieldOperationFactoryError: Error {
    case missingYieldPage
}

final class SubtensorYieldOperationFactory {
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

extension SubtensorYieldOperationFactory {
    static func makeAlphaYields(
        netuid: UInt16,
        pages: [BittensorApiResult<BittensorApi.AlphaYieldCollection>],
        logger: LoggerProtocol
    ) throws -> SubtensorAlphaYields {
        let pageStamps = pages.map { page in
            SubtensorBackendStamp(
                component: page.value.meta.components.alphaYield,
                isFromExpiredCache: page.isFromExpiredCache
            )
        }

        guard let aggregateStamp = SubtensorBackendStamp.aggregate(pageStamps) else {
            throw SubtensorYieldOperationFactoryError.missingYieldPage
        }

        var yields: [AccountId: SubtensorReportedYield] = [:]
        var seenHotkeys: Set<AccountId> = []
        var skippedRows = 0

        for (page, pageStamp) in zip(pages, pageStamps) {
            for item in page.value.items {
                guard
                    item.netuid == netuid,
                    let hotkey = try? item.hotkey.toAccountId(
                        using: .substrate(SubstrateConstants.genericAddressPrefix)
                    ) else {
                    skippedRows += 1
                    continue
                }

                guard seenHotkeys.insert(hotkey).inserted, item.rateReliability != .unreliable else {
                    continue
                }

                yields[hotkey] = SubtensorReportedYield(reportedRate: item.reportedRate, stamp: pageStamp)
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

    static func logUnverdictedRows(
        netuid: UInt16,
        pages: [BittensorApiResult<BittensorApi.AlphaYieldCollection>],
        logger: LoggerProtocol
    ) {
        let count = pages.reduce(0) { total, page in
            total + page.value.items.filter { $0.netuid == netuid && $0.rateReliability == nil }.count
        }

        if count > 0 {
            logger.warning("\(count) alpha yield rows of netuid \(netuid) carry no rate verdict; rates trusted")
        }
    }

    static func makeRootYields(
        from result: BittensorApiResult<BittensorApi.RootValidatorCollection>,
        logger: LoggerProtocol
    ) throws -> SubtensorAlphaYields {
        guard let stamp = SubtensorBackendStamp(
            metadata: result.value.meta.components.stakeYieldWindows,
            isFromExpiredCache: result.isFromExpiredCache
        ) else {
            throw SubtensorYieldOperationFactoryError.missingYieldPage
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

        return SubtensorAlphaYields(netuid: SubtensorPallet.rootNetuid, yields: yields, stamp: stamp)
    }

    static func makeNetworkRootRate(
        from result: BittensorApiResult<BittensorApi.RootOverview>
    ) -> SubtensorReportedYield? {
        guard
            let rate = result.value.stakeIndex?.stakeYield.d30?.apy,
            let stamp = SubtensorBackendStamp(
                metadata: result.value.meta.components.indexes,
                isFromExpiredCache: result.isFromExpiredCache
            ) else {
            return nil
        }

        return SubtensorReportedYield(reportedRate: rate, stamp: stamp)
    }
}

extension SubtensorYieldOperationFactory: SubtensorYieldOperationFactoryProtocol {
    func createAlphaYieldsWrapper(for netuid: UInt16) -> CompoundOperationWrapper<SubtensorAlphaYields> {
        let logger = logger

        guard netuid != SubtensorPallet.rootNetuid else {
            return apiOperationFactory.createRootValidatorsWrapper().mapped { result in
                try Self.makeRootYields(from: result, logger: logger)
            }
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

        return pagesWrapper.mapped { pages in
            Self.logUnverdictedRows(netuid: netuid, pages: pages, logger: logger)
            return try Self.makeAlphaYields(netuid: netuid, pages: pages, logger: logger)
        }
    }

    func cachedAlphaYields(for netuid: UInt16) -> HTTPCachePeek<SubtensorAlphaYields> {
        guard netuid != SubtensorPallet.rootNetuid else {
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
        apiOperationFactory.createRootOverviewWrapper().mapped { Self.makeNetworkRootRate(from: $0) }
    }
}
