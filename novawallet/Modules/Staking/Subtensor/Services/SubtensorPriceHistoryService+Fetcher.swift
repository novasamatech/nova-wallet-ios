import Foundation
import Operation_iOS

extension SubtensorPriceHistoryService {
    struct Fetcher {
        let coingeckoOperationFactory: CoingeckoOperationFactoryProtocol
        let blockNumberOperationFactory: BlockNumberOperationFactoryProtocol
        let chainId: ChainModel.Id
        let taoPriceId: AssetModel.PriceId
        let timeProvider: () -> TimeInterval
        let logger: LoggerProtocol
    }

    static func marketChanges(
        of listed: [SubtensorSubnetRef: SubtensorSubnetMarket],
        taoWeekItems: [PriceHistoryItem],
        headBlock: BlockNumber,
        at now: TimeInterval
    ) -> [SubtensorSubnetRef: SubtensorPriceData<SubtensorWeeklyPriceSummary>] {
        let taoItems = taoWeekItems.filter { $0.value > 0 }.sorted { $0.startedAt < $1.startedAt }
        let taoDate: (PriceHistoryItem) -> Date = { Date(timeIntervalSince1970: TimeInterval($0.startedAt)) }

        guard
            let taoChange = SubtensorPriceSeries.change(of: taoItems, over: .week, date: taoDate, value: \.value),
            1 + taoChange > 0 else {
            return listed.mapValues { _ in .unavailable }
        }

        return listed.reduce(into: [:]) { result, item in
            let (subnet, market) = item

            guard
                isCurrent(market, at: now),
                coversWeek(market, since: registrationDate(of: subnet, headBlock: headBlock, at: now)),
                let percent = market.weekChangePercent else {
                result[subnet] = .unavailable
                return
            }

            let summary = SubtensorWeeklyPriceSummary(
                change: (1 + percent / 100) / (1 + taoChange) - 1,
                sparkline: marketSparkline(of: market.weekSparkline, taoItems: taoItems)
            )

            result[subnet] = .available(summary)
        }
    }
}

private extension SubtensorPriceHistoryService {
    static func isCurrent(_ market: SubtensorSubnetMarket, at now: TimeInterval) -> Bool {
        guard let lastUpdated = market.lastUpdated else {
            return false
        }

        return now - lastUpdated.timeIntervalSince1970 <= marketStalenessLimit
    }

    static func coversWeek(_ market: SubtensorSubnetMarket, since registrationDate: Date) -> Bool {
        guard
            let lastUpdated = market.lastUpdated,
            let weekStart = SubtensorPricePeriod.week.startDate(endingAt: lastUpdated) else {
            return false
        }

        return registrationDate.addingTimeInterval(SubtensorPricePeriod.week.coverageTolerance) <= weekStart
    }

    static func marketSparkline(of prices: [Decimal?], taoItems: [PriceHistoryItem]) -> [Decimal] {
        guard prices.count > 1, let lastTaoItem = taoItems.last else {
            return []
        }

        let end = Date(timeIntervalSince1970: TimeInterval(lastTaoItem.startedAt))

        guard let start = SubtensorPricePeriod.week.startDate(endingAt: end) else {
            return []
        }

        let step = end.timeIntervalSince(start) / TimeInterval(prices.count - 1)

        let alphaItems = prices.enumerated().compactMap { index, price -> PriceHistoryItem? in
            let time = start.timeIntervalSince1970 + step * TimeInterval(index)

            guard let price, time >= 0 else {
                return nil
            }

            return PriceHistoryItem(startedAt: UInt64(time.rounded()), value: price)
        }

        let points = SubtensorPriceSeries.matchedPoints(
            alpha: alphaItems,
            tao: taoItems,
            tolerance: SubtensorPricePeriod.week.samplingInterval
        )

        return sparkline(of: points.map(\.taoPerAlpha))
    }
}

extension SubtensorPriceHistoryService.Fetcher {
    func createHeadBlockWrapper() -> CompoundOperationWrapper<BlockNumber> {
        blockNumberOperationFactory.createWrapper(for: chainId)
    }

    func createPointsWrapper(
        alphaPriceId: String,
        currency: Currency,
        period: SubtensorPricePeriod
    ) -> CompoundOperationWrapper<[SubtensorPricePoint]> {
        let alphaOperation = coingeckoOperationFactory.fetchPriceHistory(
            for: alphaPriceId,
            currency: currency,
            period: period.coingeckoPeriod
        )

        let taoOperation = coingeckoOperationFactory.fetchPriceHistory(
            for: taoPriceId,
            currency: currency,
            period: period.coingeckoPeriod
        )

        let pointsOperation = ClosureOperation<[SubtensorPricePoint]> {
            let alpha = try alphaOperation.extractNoCancellableResultData()
            let tao = try taoOperation.extractNoCancellableResultData()

            return SubtensorPriceSeries.matchedPoints(
                alpha: alpha.items,
                tao: tao.items,
                tolerance: period.samplingInterval
            )
        }

        pointsOperation.addDependency(alphaOperation)
        pointsOperation.addDependency(taoOperation)

        return CompoundOperationWrapper(targetOperation: pointsOperation, dependencies: [alphaOperation, taoOperation])
    }

    func createMarketChangesWrapper(
        for listed: [SubtensorSubnetRef: SubtensorSubnetMarket]
    ) -> CompoundOperationWrapper<[SubtensorSubnetRef: SubtensorPriceData<SubtensorWeeklyPriceSummary>]> {
        let taoOperation = coingeckoOperationFactory.fetchPriceHistory(
            for: taoPriceId,
            currency: .usd,
            period: SubtensorPricePeriod.week.coingeckoPeriod
        )

        let headBlockWrapper = createHeadBlockWrapper()

        let timeProvider = timeProvider
        let logger = logger

        let changesOperation = ClosureOperation<[SubtensorSubnetRef: SubtensorPriceData<SubtensorWeeklyPriceSummary>]> {
            do {
                let tao = try taoOperation.extractNoCancellableResultData()
                let headBlock = try headBlockWrapper.targetOperation.extractNoCancellableResultData()

                return SubtensorPriceHistoryService.marketChanges(
                    of: listed,
                    taoWeekItems: tao.items,
                    headBlock: headBlock,
                    at: timeProvider()
                )
            } catch {
                logger.warning("Subtensor TAO price history unavailable: \(error)")
                return [:]
            }
        }

        changesOperation.addDependency(taoOperation)
        changesOperation.addDependency(headBlockWrapper.targetOperation)

        return CompoundOperationWrapper(
            targetOperation: changesOperation,
            dependencies: [taoOperation] + headBlockWrapper.allOperations
        )
    }
}
