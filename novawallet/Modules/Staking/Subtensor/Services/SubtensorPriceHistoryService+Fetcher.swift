import Foundation
import Operation_iOS

extension SubtensorPriceHistoryService {
    struct Fetcher {
        let coingeckoOperationFactory: CoingeckoOperationFactoryProtocol
        let taoPriceId: AssetModel.PriceId
        let operationQueue: OperationQueue
        let logger: LoggerProtocol
    }

    struct ListedValue<Value: Equatable> {
        let subnet: SubtensorSubnetRef
        let value: SubtensorPriceData<Value>
    }

    static func subnetMarketChanges(
        from data: Data,
        taoWeekItems: [PriceHistoryItem],
        listed: [SubtensorSubnetRef: String]
    ) throws -> [SubtensorSubnetRef: SubtensorPriceData<SubtensorWeeklyPriceSummary>] {
        let markets = try JSONDecoder().decode([SubnetMarket].self, from: data)

        let taoItems = taoWeekItems.filter { $0.value > 0 }.sorted { $0.startedAt < $1.startedAt }
        let taoDate: (PriceHistoryItem) -> Date = { Date(timeIntervalSince1970: TimeInterval($0.startedAt)) }

        guard
            let taoChange = SubtensorPriceSeries.change(of: taoItems, over: .week, date: taoDate, value: \.value),
            1 + taoChange > 0 else {
            return listed.mapValues { _ in .unavailable }
        }

        let marketsById = markets.reduce(into: [String: SubnetMarket]()) { result, market in
            guard result[market.id] == nil, market.priceChangePercentage7dInCurrency != nil else {
                return
            }

            result[market.id] = market
        }

        return listed.mapValues { coingeckoId in
            guard
                let market = marketsById[coingeckoId],
                let percent = market.priceChangePercentage7dInCurrency else {
                return .unavailable
            }

            let summary = SubtensorWeeklyPriceSummary(
                change: (1 + percent / 100) / (1 + taoChange) - 1,
                sparkline: marketSparkline(of: market.sparklineIn7d?.price ?? [], taoItems: taoItems)
            )

            return .available(summary)
        }
    }
}

private extension SubtensorPriceHistoryService {
    struct SubnetMarket: Decodable {
        enum CodingKeys: String, CodingKey {
            case id
            case priceChangePercentage7dInCurrency = "price_change_percentage_7d_in_currency"
            case sparklineIn7d = "sparkline_in_7d"
        }

        struct Sparkline: Decodable {
            let price: [Decimal?]?
        }

        let id: String
        let priceChangePercentage7dInCurrency: Decimal?
        let sparklineIn7d: Sparkline?
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

    func createChartValuesWrapper<Value: Equatable>(
        for listed: [SubtensorSubnetRef: String],
        period: SubtensorPricePeriod,
        evaluate: @escaping ([SubtensorPricePoint]) -> Value?
    ) -> CompoundOperationWrapper<[SubtensorSubnetRef: SubtensorPriceData<Value>]> {
        let taoOperation = coingeckoOperationFactory.fetchPriceHistory(
            for: taoPriceId,
            currency: .usd,
            period: period.coingeckoPeriod
        )

        let subnets = listed.sorted { $0.key.netuid < $1.key.netuid }
        let fetcher = self
        let logger = logger

        let valuesOperation = OperationCombiningService<SubtensorPriceHistoryService.ListedValue<Value>>(
            operationManager: OperationManager(operationQueue: operationQueue),
            operationsPerBatch: SubtensorPriceHistoryService.alphaChartConcurrency
        ) {
            let taoItems: [PriceHistoryItem]

            do {
                taoItems = try taoOperation.extractNoCancellableResultData().items
            } catch {
                logger.warning("Subtensor TAO price history unavailable: \(error)")
                return []
            }

            return subnets.map { subnet, alphaPriceId in
                fetcher.createChartValueWrapper(
                    for: subnet,
                    alphaPriceId: alphaPriceId,
                    period: period,
                    taoItems: taoItems,
                    evaluate: evaluate
                )
            }
        }.longrunOperation()

        valuesOperation.addDependency(taoOperation)

        let resultOperation = ClosureOperation<[SubtensorSubnetRef: SubtensorPriceData<Value>]> {
            try valuesOperation.extractNoCancellableResultData().reduce(into: [:]) { result, listedValue in
                result[listedValue.subnet] = listedValue.value
            }
        }

        resultOperation.addDependency(valuesOperation)

        return CompoundOperationWrapper(
            targetOperation: resultOperation,
            dependencies: [taoOperation, valuesOperation]
        )
    }

    func createSubnetMarketChangesWrapper(
        for listed: [SubtensorSubnetRef: String]
    ) -> CompoundOperationWrapper<[SubtensorSubnetRef: SubtensorPriceData<SubtensorWeeklyPriceSummary>]> {
        let marketsOperation = createSubnetMarketsOperation()

        let taoOperation = coingeckoOperationFactory.fetchPriceHistory(
            for: taoPriceId,
            currency: .usd,
            period: SubtensorPricePeriod.week.coingeckoPeriod
        )

        let logger = logger

        let changesOperation = ClosureOperation<[SubtensorSubnetRef: SubtensorPriceData<SubtensorWeeklyPriceSummary>]> {
            do {
                let markets = try marketsOperation.extractNoCancellableResultData()
                let tao = try taoOperation.extractNoCancellableResultData()

                return try SubtensorPriceHistoryService.subnetMarketChanges(
                    from: markets,
                    taoWeekItems: tao.items,
                    listed: listed
                )
            } catch {
                logger.warning("Subtensor subnet markets unavailable: \(error)")
                return [:]
            }
        }

        changesOperation.addDependency(marketsOperation)
        changesOperation.addDependency(taoOperation)

        return CompoundOperationWrapper(
            targetOperation: changesOperation,
            dependencies: [marketsOperation, taoOperation]
        )
    }
}

private extension SubtensorPriceHistoryService.Fetcher {
    func createChartValueWrapper<Value: Equatable>(
        for subnet: SubtensorSubnetRef,
        alphaPriceId: String,
        period: SubtensorPricePeriod,
        taoItems: [PriceHistoryItem],
        evaluate: @escaping ([SubtensorPricePoint]) -> Value?
    ) -> CompoundOperationWrapper<SubtensorPriceHistoryService.ListedValue<Value>> {
        let alphaOperation = coingeckoOperationFactory.fetchPriceHistory(
            for: alphaPriceId,
            currency: .usd,
            period: period.coingeckoPeriod
        )

        let logger = logger

        let valueOperation = ClosureOperation<SubtensorPriceHistoryService.ListedValue<Value>> {
            do {
                let alpha = try alphaOperation.extractNoCancellableResultData()

                let points = SubtensorPriceSeries.matchedPoints(
                    alpha: alpha.items,
                    tao: taoItems,
                    tolerance: period.samplingInterval
                )

                guard let value = evaluate(points) else {
                    return SubtensorPriceHistoryService.ListedValue(subnet: subnet, value: .unavailable)
                }

                return SubtensorPriceHistoryService.ListedValue(subnet: subnet, value: .available(value))
            } catch {
                logger.warning("Subtensor price history of netuid \(subnet.netuid) unavailable: \(error)")

                return SubtensorPriceHistoryService.ListedValue(subnet: subnet, value: .unavailable)
            }
        }

        valueOperation.addDependency(alphaOperation)

        return CompoundOperationWrapper(targetOperation: valueOperation, dependencies: [alphaOperation])
    }

    func createSubnetMarketsOperation() -> BaseOperation<Data> {
        guard var components = URLComponents(
            url: PriceAPI.proxyBaseURL.appendingPathComponent("coins/markets"),
            resolvingAgainstBaseURL: false
        ) else {
            return BaseOperation.createWithError(NetworkBaseError.invalidUrl)
        }

        components.queryItems = [
            URLQueryItem(name: "vs_currency", value: Currency.usd.coingeckoId),
            URLQueryItem(name: "category", value: SubtensorPriceHistoryService.subnetMarketsCategory),
            URLQueryItem(name: "price_change_percentage", value: "7d"),
            URLQueryItem(name: "sparkline", value: "true"),
            URLQueryItem(name: "per_page", value: String(SubtensorPriceHistoryService.subnetMarketsPageSize)),
            URLQueryItem(name: "page", value: "1")
        ]

        guard let url = components.url else {
            return BaseOperation.createWithError(NetworkBaseError.invalidUrl)
        }

        let requestFactory = BlockNetworkRequestFactory {
            var request = URLRequest(url: url)
            request.httpMethod = HttpMethod.get.rawValue
            return request
        }

        return NetworkOperation(
            requestFactory: requestFactory,
            resultFactory: AnyNetworkResultFactory<Data>(processingBlock: { $0 })
        )
    }
}
