import Foundation
import Operation_iOS

enum SubtensorYieldOperationFactoryError: Error {
    case missingYieldPage
}

final class SubtensorYieldOperationFactory {
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
        result: BittensorApiResult<BittensorApi.AlphaYieldCollection>,
        logger: LoggerProtocol
    ) -> SubtensorAlphaYields {
        let stamp = SubtensorBackendStamp(
            component: result.value.meta.components.alphaYield,
            isFromExpiredCache: result.isFromExpiredCache
        )

        var yields: [AccountId: SubtensorReportedYield] = [:]
        var skippedRows = 0

        for item in result.value.items {
            guard
                item.netuid == netuid,
                let hotkey = try? item.hotkey.toAccountId(
                    using: .substrate(SubstrateConstants.genericAddressPrefix)
                ) else {
                skippedRows += 1
                continue
            }

            guard yields[hotkey] == nil else {
                continue
            }

            yields[hotkey] = SubtensorReportedYield(
                reportedRate: item.reportedRate,
                stamp: stamp,
                isReliable: item.rateReliability != .unreliable
            )
        }

        if skippedRows > 0 {
            logger.warning("Skipped \(skippedRows) alpha yield rows of netuid \(netuid)")
        }

        return SubtensorAlphaYields(netuid: netuid, yields: yields, stamp: stamp)
    }

    static func logFetchedAlphaYields(
        netuid: UInt16,
        collection: BittensorApi.AlphaYieldCollection,
        logger: LoggerProtocol
    ) {
        let count = collection.items.filter { $0.netuid == netuid && $0.rateReliability == nil }.count

        if count > 0 {
            logger.warning("\(count) alpha yield rows of netuid \(netuid) carry no rate verdict; rates trusted")
        }

        if collection.pageInfo.nextPage != nil {
            logger.warning("Alpha yields of netuid \(netuid) list \(collection.pageInfo.total) rows; first page kept")
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

        return apiOperationFactory.createAlphaYieldWrapper(netuid: netuid).mapped { result in
            Self.logFetchedAlphaYields(netuid: netuid, collection: result.value, logger: logger)
            return Self.makeAlphaYields(netuid: netuid, result: result, logger: logger)
        }
    }

    func cachedAlphaYields(for netuid: UInt16) -> HTTPCachePeek<SubtensorAlphaYields> {
        guard netuid != SubtensorPallet.rootNetuid else {
            return apiOperationFactory.peekRootValidators().map { try Self.makeRootYields(from: $0, logger: logger) }
        }

        return apiOperationFactory.peekAlphaYield(netuid: netuid).map {
            Self.makeAlphaYields(netuid: netuid, result: $0, logger: logger)
        }
    }

    func createNetworkRootRateWrapper() -> CompoundOperationWrapper<SubtensorReportedYield?> {
        apiOperationFactory.createRootOverviewWrapper().mapped { Self.makeNetworkRootRate(from: $0) }
    }
}
