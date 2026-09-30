import Foundation
import Operation_iOS

#if F_SUBTENSOR_MARKETS_STUB
    final class SubtensorSubnetMarketsStubFallback {
        let service: SubtensorSubnetMarketsServiceProtocol
        let timeProvider: () -> TimeInterval
        let logger: LoggerProtocol

        init(
            service: SubtensorSubnetMarketsServiceProtocol,
            timeProvider: @escaping () -> TimeInterval = { Date().timeIntervalSince1970 },
            logger: LoggerProtocol = Logger.shared
        ) {
            self.service = service
            self.timeProvider = timeProvider
            self.logger = logger
        }
    }

    extension SubtensorSubnetMarketsStubFallback: SubtensorSubnetMarketsServiceProtocol {
        func createMarketsWrapper() -> CompoundOperationWrapper<SubtensorSubnetMarkets> {
            let wrapper = service.createMarketsWrapper()
            let timeProvider = timeProvider
            let logger = logger

            let marketsOperation = ClosureOperation<SubtensorSubnetMarkets> {
                do {
                    return try wrapper.targetOperation.extractNoCancellableResultData()
                } catch {
                    logger.warning("Subtensor subnet markets fall back to the bundled stub: \(error)")

                    return try Self.loadStub(movedTo: timeProvider())
                }
            }

            marketsOperation.addDependency(wrapper.targetOperation)

            return wrapper.insertingTail(operation: marketsOperation)
        }
    }

    private extension SubtensorSubnetMarketsStubFallback {
        static func loadStub(movedTo time: TimeInterval) throws -> SubtensorSubnetMarkets {
            guard let url = R.file.subtensorSubnetMarketsStubJson() else {
                throw CommonError.dataCorruption
            }

            let markets = try JSONDecoder().decode(SubtensorSubnetMarkets.self, from: Data(contentsOf: url))

            guard let capturedAt = markets.byNetuid.values.compactMap(\.lastUpdated).max() else {
                return markets
            }

            let captureAge = time - capturedAt.timeIntervalSince1970

            return SubtensorSubnetMarkets(byNetuid: markets.byNetuid.mapValues { market in
                SubtensorSubnetMarket(
                    coingeckoId: market.coingeckoId,
                    weekChangePercent: market.weekChangePercent,
                    weekSparkline: market.weekSparkline,
                    lastUpdated: market.lastUpdated?.addingTimeInterval(captureAge)
                )
            })
        }
    }
#endif
