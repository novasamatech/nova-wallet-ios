import Foundation
import Operation_iOS

enum SubtensorWeeklyChangeSource {
    case alphaMarketCharts
    case subnetMarkets
}

final class SubtensorPriceHistoryService {
    static let weeklyChangeSource = SubtensorWeeklyChangeSource.alphaMarketCharts
    static let weeklyChangeConcurrency = 4
    static let subnetMarketsCategory = "bittensor-subnets"
    static let subnetMarketsPageSize = 250

    let earnConfigProvider: SubtensorEarnConfigProviderProtocol
    let coingeckoOperationFactory: CoingeckoOperationFactoryProtocol
    let taoPriceId: AssetModel.PriceId
    let operationQueue: OperationQueue
    let logger: LoggerProtocol

    init(
        earnConfigProvider: SubtensorEarnConfigProviderProtocol,
        coingeckoOperationFactory: CoingeckoOperationFactoryProtocol,
        taoPriceId: AssetModel.PriceId,
        operationQueue: OperationQueue,
        logger: LoggerProtocol = Logger.shared
    ) {
        self.earnConfigProvider = earnConfigProvider
        self.coingeckoOperationFactory = coingeckoOperationFactory
        self.taoPriceId = taoPriceId
        self.operationQueue = operationQueue
        self.logger = logger
    }
}

extension SubtensorPriceHistoryService {
    static func coingeckoId(in config: SubtensorEarnConfig, for subnet: SubtensorSubnetRef) -> String? {
        let rawId = config.subnetEntry(for: subnet)?.coingeckoId

        guard
            let coingeckoId = rawId?.trimmingCharacters(in: .whitespacesAndNewlines),
            !coingeckoId.isEmpty,
            coingeckoId.unicodeScalars.allSatisfy({ coingeckoIdCharacters.contains($0) }) else {
            return nil
        }

        return coingeckoId
    }

    static func makeHistory(
        subnet: SubtensorSubnetRef,
        period: SubtensorPricePeriod,
        points: [SubtensorPricePoint]
    ) -> SubtensorPriceHistory {
        let periodPoints = SubtensorPriceSeries.sliced(points, for: period, date: \.date)

        return SubtensorPriceHistory(
            subnet: subnet,
            period: period,
            points: periodPoints,
            changeInTao: SubtensorPriceSeries.change(
                of: periodPoints,
                over: period,
                date: \.date,
                value: \.taoPerAlpha
            ),
            changeInFiat: SubtensorPriceSeries.change(
                of: periodPoints,
                over: period,
                date: \.date,
                value: \.fiatPerAlpha
            )
        )
    }

    static func subnetMarketChanges(
        from data: Data,
        taoWeekItems: [PriceHistoryItem],
        listed: [SubtensorSubnetRef: String]
    ) throws -> [SubtensorSubnetRef: Decimal] {
        let markets = try JSONDecoder().decode([SubnetMarket].self, from: data)

        let taoItems = taoWeekItems.filter { $0.value > 0 }.sorted { $0.startedAt < $1.startedAt }
        let taoDate: (PriceHistoryItem) -> Date = { Date(timeIntervalSince1970: TimeInterval($0.startedAt)) }

        guard
            let taoChange = SubtensorPriceSeries.change(of: taoItems, over: .week, date: taoDate, value: \.value),
            1 + taoChange > 0 else {
            return [:]
        }

        let alphaChanges = markets.reduce(into: [String: Decimal]()) { result, market in
            guard result[market.id] == nil, let percent = market.priceChangePercentage7dInCurrency else {
                return
            }

            result[market.id] = percent / 100
        }

        return listed.reduce(into: [:]) { result, entry in
            guard let alphaChange = alphaChanges[entry.value] else {
                return
            }

            result[entry.key] = (1 + alphaChange) / (1 + taoChange) - 1
        }
    }
}

private extension SubtensorPriceHistoryService {
    struct SubnetMarket: Decodable {
        enum CodingKeys: String, CodingKey {
            case id
            case priceChangePercentage7dInCurrency = "price_change_percentage_7d_in_currency"
        }

        let id: String
        let priceChangePercentage7dInCurrency: Decimal?
    }

    struct WeeklyChange {
        let subnet: SubtensorSubnetRef
        let value: Decimal?
    }

    struct Fetcher {
        let coingeckoOperationFactory: CoingeckoOperationFactoryProtocol
        let taoPriceId: AssetModel.PriceId
        let operationQueue: OperationQueue
        let logger: LoggerProtocol
    }

    static let coingeckoIdCharacters = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789-")

    static func listedIds(
        for subnets: [SubtensorSubnetRef],
        in config: SubtensorEarnConfig
    ) -> [SubtensorSubnetRef: String] {
        subnets.reduce(into: [:]) { result, subnet in
            result[subnet] = coingeckoId(in: config, for: subnet)
        }
    }

    var fetcher: Fetcher {
        Fetcher(
            coingeckoOperationFactory: coingeckoOperationFactory,
            taoPriceId: taoPriceId,
            operationQueue: operationQueue,
            logger: logger
        )
    }
}

private extension SubtensorPriceHistoryService.Fetcher {
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

    func createAlphaChartChangeWrapper(
        for subnet: SubtensorSubnetRef,
        alphaPriceId: String,
        taoItems: [PriceHistoryItem]
    ) -> CompoundOperationWrapper<SubtensorPriceHistoryService.WeeklyChange> {
        let alphaOperation = coingeckoOperationFactory.fetchPriceHistory(
            for: alphaPriceId,
            currency: Currency.usd,
            period: SubtensorPricePeriod.week.coingeckoPeriod
        )

        let logger = logger

        let changeOperation = ClosureOperation<SubtensorPriceHistoryService.WeeklyChange> {
            do {
                let alpha = try alphaOperation.extractNoCancellableResultData()

                let points = SubtensorPriceSeries.matchedPoints(
                    alpha: alpha.items,
                    tao: taoItems,
                    tolerance: SubtensorPricePeriod.week.samplingInterval
                )

                let change = SubtensorPriceSeries.change(of: points, over: .week, date: \.date, value: \.taoPerAlpha)

                return .init(subnet: subnet, value: change)
            } catch {
                logger.warning("Subtensor 7-day change of netuid \(subnet.netuid) unavailable: \(error)")

                return .init(subnet: subnet, value: nil)
            }
        }

        changeOperation.addDependency(alphaOperation)

        return CompoundOperationWrapper(targetOperation: changeOperation, dependencies: [alphaOperation])
    }

    func createAlphaChartChangesWrapper(
        for listed: [SubtensorSubnetRef: String]
    ) -> CompoundOperationWrapper<[SubtensorSubnetRef: Decimal]> {
        let taoOperation = coingeckoOperationFactory.fetchPriceHistory(
            for: taoPriceId,
            currency: Currency.usd,
            period: SubtensorPricePeriod.week.coingeckoPeriod
        )

        let subnets = listed.sorted { $0.key.netuid < $1.key.netuid }
        let fetcher = self

        let changesOperation = OperationCombiningService<SubtensorPriceHistoryService.WeeklyChange>(
            operationManager: OperationManager(operationQueue: operationQueue),
            operationsPerBatch: SubtensorPriceHistoryService.weeklyChangeConcurrency
        ) {
            let taoItems = try taoOperation.extractNoCancellableResultData().items

            return subnets.map { subnet, alphaPriceId in
                fetcher.createAlphaChartChangeWrapper(for: subnet, alphaPriceId: alphaPriceId, taoItems: taoItems)
            }
        }.longrunOperation()

        changesOperation.addDependency(taoOperation)

        let resultOperation = ClosureOperation<[SubtensorSubnetRef: Decimal]> {
            try changesOperation.extractNoCancellableResultData().reduce(into: [:]) { result, change in
                result[change.subnet] = change.value
            }
        }

        resultOperation.addDependency(changesOperation)

        return CompoundOperationWrapper(
            targetOperation: resultOperation,
            dependencies: [taoOperation, changesOperation]
        )
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

    func createSubnetMarketChangesWrapper(
        for listed: [SubtensorSubnetRef: String]
    ) -> CompoundOperationWrapper<[SubtensorSubnetRef: Decimal]> {
        let marketsOperation = createSubnetMarketsOperation()

        let taoOperation = coingeckoOperationFactory.fetchPriceHistory(
            for: taoPriceId,
            currency: Currency.usd,
            period: SubtensorPricePeriod.week.coingeckoPeriod
        )

        let changesOperation = ClosureOperation<[SubtensorSubnetRef: Decimal]> {
            let markets = try marketsOperation.extractNoCancellableResultData()
            let tao = try taoOperation.extractNoCancellableResultData()

            return try SubtensorPriceHistoryService.subnetMarketChanges(
                from: markets,
                taoWeekItems: tao.items,
                listed: listed
            )
        }

        changesOperation.addDependency(marketsOperation)
        changesOperation.addDependency(taoOperation)

        return CompoundOperationWrapper(
            targetOperation: changesOperation,
            dependencies: [marketsOperation, taoOperation]
        )
    }
}

extension SubtensorPriceHistoryService: SubtensorPriceHistoryServiceProtocol {
    func createHistoryWrapper(
        for subnet: SubtensorSubnetRef,
        period: SubtensorPricePeriod,
        currency: Currency
    ) -> CompoundOperationWrapper<SubtensorPriceHistoryResult> {
        let configWrapper = earnConfigProvider.createConfigWrapper()
        let fetcher = fetcher

        let pointsWrapper: CompoundOperationWrapper<[SubtensorPricePoint]?> = OperationCombiningService.compoundWrapper(
            operationManager: OperationManager(operationQueue: operationQueue)
        ) {
            let config = try configWrapper.targetOperation.extractNoCancellableResultData()

            guard let alphaPriceId = Self.coingeckoId(in: config, for: subnet) else {
                return nil
            }

            return fetcher.createPointsWrapper(alphaPriceId: alphaPriceId, currency: currency, period: period)
        }

        pointsWrapper.addDependency(wrapper: configWrapper)

        let resultOperation = ClosureOperation<SubtensorPriceHistoryResult> {
            guard let points = try pointsWrapper.targetOperation.extractNoCancellableResultData() else {
                return .notListed
            }

            return .available(Self.makeHistory(subnet: subnet, period: period, points: points))
        }

        resultOperation.addDependency(pointsWrapper.targetOperation)

        return CompoundOperationWrapper(
            targetOperation: resultOperation,
            dependencies: configWrapper.allOperations + pointsWrapper.allOperations
        )
    }

    func createWeeklyChangesWrapper(
        for subnets: [SubtensorSubnetRef]
    ) -> CompoundOperationWrapper<[SubtensorSubnetRef: Decimal]> {
        let configWrapper = earnConfigProvider.createConfigWrapper()
        let fetcher = fetcher

        let changesWrapper: CompoundOperationWrapper<[SubtensorSubnetRef: Decimal]> =
            OperationCombiningService.compoundNonOptionalWrapper(operationQueue: operationQueue) {
                let config = try configWrapper.targetOperation.extractNoCancellableResultData()
                let listed = Self.listedIds(for: subnets, in: config)

                guard !listed.isEmpty else {
                    return .createWithResult([:])
                }

                switch Self.weeklyChangeSource {
                case .alphaMarketCharts:
                    return fetcher.createAlphaChartChangesWrapper(for: listed)
                case .subnetMarkets:
                    return fetcher.createSubnetMarketChangesWrapper(for: listed)
                }
            }

        changesWrapper.addDependency(wrapper: configWrapper)

        return changesWrapper.insertingHead(operations: configWrapper.allOperations)
    }
}
