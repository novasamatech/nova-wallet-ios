import Foundation
import Operation_iOS

final class SubtensorPriceHistoryService {
    static let sparklineMaxCount = 48
    static let notListedTimeToLive = TimeInterval(15).secondsFromMinutes
    static let marketStalenessLimit = TimeInterval(24).secondsFromHours

    let marketsService: SubtensorSubnetMarketsServiceProtocol
    let seriesProvider: SubtensorPriceSeriesProviding
    let blockNumberOperationFactory: BlockNumberOperationFactoryProtocol
    let chainId: ChainModel.Id
    let taoPriceId: AssetModel.PriceId
    let operationQueue: OperationQueue
    let timeProvider: () -> TimeInterval
    let logger: LoggerProtocol

    init(
        marketsService: SubtensorSubnetMarketsServiceProtocol,
        seriesProvider: SubtensorPriceSeriesProviding,
        blockNumberOperationFactory: BlockNumberOperationFactoryProtocol,
        chainId: ChainModel.Id,
        taoPriceId: AssetModel.PriceId,
        operationQueue: OperationQueue,
        timeProvider: @escaping () -> TimeInterval = { Date().timeIntervalSince1970 },
        logger: LoggerProtocol = Logger.shared
    ) {
        self.marketsService = marketsService
        self.seriesProvider = seriesProvider
        self.blockNumberOperationFactory = blockNumberOperationFactory
        self.chainId = chainId
        self.taoPriceId = taoPriceId
        self.operationQueue = operationQueue
        self.timeProvider = timeProvider
        self.logger = logger
    }
}

extension SubtensorPriceHistoryService {
    static func registrationDate(
        of subnet: SubtensorSubnetRef,
        headBlock: BlockNumber,
        at now: TimeInterval
    ) -> Date {
        let head = UInt64(headBlock)
        let elapsedBlocks = head - min(subnet.registeredAt, head)
        let blockTimeMillis = TimeInterval(SubtensorStakingFlowConstants.blockTimeMillis)
        let elapsed = (TimeInterval(elapsedBlocks) * blockTimeMillis).seconds

        return Date(timeIntervalSince1970: now - elapsed)
    }

    static func makeHistory(
        subnet: SubtensorSubnetRef,
        period: SubtensorPricePeriod,
        points: [SubtensorPricePoint],
        registrationDate: Date
    ) -> SubtensorPriceHistory {
        let registeredPoints = points.filter { $0.date >= registrationDate }
        let periodPoints = SubtensorPriceSeries.sliced(registeredPoints, for: period, date: \.date)

        let coversPeriod = periodPoints.last
            .flatMap { period.startDate(endingAt: $0.date) }
            .map { registrationDate <= $0 } ?? true

        guard coversPeriod else {
            return SubtensorPriceHistory(
                subnet: subnet,
                period: period,
                points: periodPoints,
                changeInTao: nil,
                changeInFiat: nil
            )
        }

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

    static func sparkline(of values: [Decimal]) -> [Decimal] {
        guard values.count > sparklineMaxCount else {
            return values
        }

        let step = (values.count + sparklineMaxCount - 1) / sparklineMaxCount
        let lastIndex = values.count - 1

        return stride(from: lastIndex % step, through: lastIndex, by: step).map { values[$0] }
    }

    static func priceData<Value: Equatable>(
        for subnets: [SubtensorSubnetRef],
        listed: [SubtensorSubnetRef: SubtensorSubnetMarket],
        values: [SubtensorSubnetRef: SubtensorPriceData<Value>]
    ) -> [SubtensorSubnetRef: SubtensorPriceData<Value>] {
        subnets.reduce(into: [:]) { result, subnet in
            guard listed[subnet] != nil else {
                result[subnet] = .notListed
                return
            }

            result[subnet] = values[subnet] ?? .unavailable
        }
    }
}

private extension SubtensorPriceHistoryService {
    static func listedMarkets(
        for subnets: [SubtensorSubnetRef],
        in markets: SubtensorSubnetMarkets
    ) -> [SubtensorSubnetRef: SubtensorSubnetMarket] {
        subnets.reduce(into: [:]) { result, subnet in
            result[subnet] = markets.market(for: subnet.netuid)
        }
    }

    var fetcher: Fetcher {
        Fetcher(
            seriesProvider: seriesProvider,
            blockNumberOperationFactory: blockNumberOperationFactory,
            chainId: chainId,
            taoPriceId: taoPriceId,
            timeProvider: timeProvider,
            logger: logger
        )
    }

    func createPriceDataWrapper<Value: Equatable>(
        for subnets: [SubtensorSubnetRef],
        listedValuesWrapper: @escaping ([SubtensorSubnetRef: SubtensorSubnetMarket])
            -> CompoundOperationWrapper<[SubtensorSubnetRef: SubtensorPriceData<Value>]>
    ) -> CompoundOperationWrapper<[SubtensorSubnetRef: SubtensorPriceData<Value>]> {
        let marketsWrapper = marketsService.createMarketsWrapper()

        let pricesWrapper: CompoundOperationWrapper<[SubtensorSubnetRef: SubtensorPriceData<Value>]> =
            OperationCombiningService.compoundNonOptionalWrapper(operationQueue: operationQueue) {
                let markets = try marketsWrapper.targetOperation.extractNoCancellableResultData()
                let listed = Self.listedMarkets(for: subnets, in: markets)

                let valuesWrapper: CompoundOperationWrapper<[SubtensorSubnetRef: SubtensorPriceData<Value>]> =
                    listed.isEmpty ? .createWithResult([:]) : listedValuesWrapper(listed)

                let resultOperation = ClosureOperation<[SubtensorSubnetRef: SubtensorPriceData<Value>]> {
                    let values = try valuesWrapper.targetOperation.extractNoCancellableResultData()

                    return Self.priceData(for: subnets, listed: listed, values: values)
                }

                resultOperation.addDependency(valuesWrapper.targetOperation)

                return valuesWrapper.insertingTail(operation: resultOperation)
            }

        pricesWrapper.addDependency(wrapper: marketsWrapper)

        return pricesWrapper.insertingHead(operations: marketsWrapper.allOperations)
    }
}

extension SubtensorPriceHistoryService: SubtensorPriceHistoryServiceProtocol {
    func createHistoryEntryWrapper(
        for subnet: SubtensorSubnetRef,
        period: SubtensorPricePeriod,
        currency: Currency
    ) -> CompoundOperationWrapper<SubtensorPriceHistoryEntry> {
        let marketsWrapper = marketsService.createMarketsWrapper()
        let fetcher = fetcher
        let headBlockWrapper = fetcher.createHeadBlockWrapper()
        let timeProvider = timeProvider
        let seriesProvider = seriesProvider
        let taoPriceId = taoPriceId

        let pointsWrapper: CompoundOperationWrapper<[SubtensorPricePoint]?> = OperationCombiningService.compoundWrapper(
            operationManager: OperationManager(operationQueue: operationQueue)
        ) {
            let markets = try marketsWrapper.targetOperation.extractNoCancellableResultData()

            guard let alphaPriceId = markets.market(for: subnet.netuid)?.coingeckoId else {
                return nil
            }

            return fetcher.createPointsWrapper(alphaPriceId: alphaPriceId, currency: currency, period: period)
        }

        pointsWrapper.addDependency(wrapper: marketsWrapper)

        let resultOperation = ClosureOperation<SubtensorPriceHistoryEntry> {
            let now = Date(timeIntervalSince1970: timeProvider())
            let markets = try marketsWrapper.targetOperation.extractNoCancellableResultData()

            guard
                let points = try pointsWrapper.targetOperation.extractNoCancellableResultData(),
                let alphaPriceId = markets.market(for: subnet.netuid)?.coingeckoId else {
                return SubtensorPriceHistoryEntry(
                    result: .notListed,
                    expiresAt: now.addingTimeInterval(Self.notListedTimeToLive)
                )
            }

            let headBlock = try headBlockWrapper.targetOperation.extractNoCancellableResultData()
            let registrationDate = Self.registrationDate(of: subnet, headBlock: headBlock, at: timeProvider())

            let seriesExpirations = [alphaPriceId, taoPriceId].map { priceId in
                seriesProvider.expirationDate(
                    for: priceId,
                    currency: currency,
                    period: period.sourcePeriod.coingeckoPeriod
                )
            }

            let expiresAt = seriesExpirations.contains(nil) ? now : seriesExpirations.compactMap { $0 }.min() ?? now

            return SubtensorPriceHistoryEntry(
                result: .available(
                    Self.makeHistory(subnet: subnet, period: period, points: points, registrationDate: registrationDate)
                ),
                expiresAt: expiresAt
            )
        }

        resultOperation.addDependency(pointsWrapper.targetOperation)
        resultOperation.addDependency(headBlockWrapper.targetOperation)

        return CompoundOperationWrapper(
            targetOperation: resultOperation,
            dependencies: marketsWrapper.allOperations + headBlockWrapper.allOperations + pointsWrapper.allOperations
        )
    }

    func createWeeklyChangesWrapper(
        for subnets: [SubtensorSubnetRef]
    ) -> CompoundOperationWrapper<[SubtensorSubnetRef: SubtensorPriceData<SubtensorWeeklyPriceSummary>]> {
        let fetcher = fetcher

        return createPriceDataWrapper(for: subnets) { listed in
            fetcher.createMarketChangesWrapper(for: listed)
        }
    }
}
