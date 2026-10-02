import Foundation
import Operation_iOS

enum SubtensorYieldServiceError: Error {
    case missingYieldPage
}

final class SubtensorYieldService {
    static let alphaYieldPageLimit = 3
    static let rootYieldPage = 1

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
            stamp: aggregateStamp,
            isTruncated: pages.hasMorePages
        )
    }

    static func makeRootYield(
        from page: BittensorApiResult<BittensorApi.RootYieldCollection>
    ) -> SubtensorReportedYield? {
        guard let item = page.value.items.first else {
            return nil
        }

        return SubtensorReportedYield(
            reportedRate: item.reportedRate,
            stamp: SubtensorBackendStamp(
                component: page.value.meta.components.rootYield,
                isFromExpiredCache: page.isFromExpiredCache
            )
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

    func cachedAlphaYields(for netuid: UInt16) -> HTTPCachePeek<SubtensorAlphaYields> {
        let pagesPeek = BittensorApiPagination.peekPages(
            maxPages: Self.alphaYieldPageLimit,
            nextPage: { $0.pageInfo.nextPage },
            peekPage: { page in
                apiOperationFactory.peekAlphaYield(netuid: netuid, page: page)
            }
        )

        return pagesPeek.map { try Self.makeAlphaYields(netuid: netuid, pages: $0, logger: logger) }
    }

    func createRootYieldWrapper() -> CompoundOperationWrapper<SubtensorReportedYield?> {
        let pageWrapper = apiOperationFactory.createRootYieldWrapper(page: Self.rootYieldPage)
        let logger = logger

        let yieldOperation = ClosureOperation<SubtensorReportedYield?> {
            do {
                let page = try pageWrapper.targetOperation.extractNoCancellableResultData()

                return Self.makeRootYield(from: page)
            } catch {
                logger.warning("Root yield unavailable: \(error)")

                return nil
            }
        }

        yieldOperation.addDependency(pageWrapper.targetOperation)

        return pageWrapper.insertingTail(operation: yieldOperation)
    }

    func cachedRootYield() -> HTTPCachePeek<SubtensorReportedYield?> {
        apiOperationFactory.peekRootYield(page: Self.rootYieldPage).map(Self.makeRootYield(from:))
    }
}
