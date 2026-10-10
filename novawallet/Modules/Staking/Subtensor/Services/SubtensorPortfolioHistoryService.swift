import Foundation
import Operation_iOS

enum SubtensorPortfolioHistoryServiceError: Error {
    case unsupportedPeriod(SubtensorPricePeriod)
    case invalidResponse(String)
}

final class SubtensorPortfolioHistoryService {
    let apiOperationFactory: BittensorApiOperationFactoryProtocol

    init(apiOperationFactory: BittensorApiOperationFactoryProtocol) {
        self.apiOperationFactory = apiOperationFactory
    }
}

extension SubtensorPortfolioHistoryService: SubtensorPortfolioHistoryServiceProtocol {
    func createHistoryWrapper(
        for accountSubject: AccountAddress,
        period: SubtensorPricePeriod
    ) -> CompoundOperationWrapper<SubtensorPortfolioStakeHistory> {
        guard let apiPeriod = period.portfolioHistoryPeriod else {
            return .createWithError(SubtensorPortfolioHistoryServiceError.unsupportedPeriod(period))
        }

        let collectionWrapper = apiOperationFactory.createPortfolioHistoryWrapper(
            accountSubject: accountSubject,
            period: apiPeriod
        )

        let mappingOperation = ClosureOperation<SubtensorPortfolioStakeHistory> {
            let collection = try collectionWrapper.targetOperation.extractNoCancellableResultData().value

            return try Self.makeHistory(from: collection, period: period)
        }

        mappingOperation.addDependency(collectionWrapper.targetOperation)

        return collectionWrapper.insertingTail(operation: mappingOperation)
    }
}

private extension SubtensorPortfolioHistoryService {
    static func makeHistory(
        from collection: BittensorApi.PortfolioHistoryCollection,
        period: SubtensorPricePeriod
    ) throws -> SubtensorPortfolioStakeHistory {
        guard
            let windowStart = BittensorApi.instant(from: collection.window.start),
            let windowEnd = BittensorApi.instant(from: collection.window.end) else {
            throw SubtensorPortfolioHistoryServiceError.invalidResponse("window")
        }

        let points = try collection.points.map(makePoint)

        return SubtensorPortfolioStakeHistory(
            period: period,
            windowStart: windowStart,
            windowEnd: windowEnd,
            points: points
        )
    }

    static func makePoint(_ point: BittensorApi.PortfolioHistoryPoint) throws -> SubtensorPortfolioStakePoint {
        guard let date = BittensorApi.instant(from: point.timestamp) else {
            throw SubtensorPortfolioHistoryServiceError.invalidResponse("timestamp")
        }

        do {
            return SubtensorPortfolioStakePoint(
                date: date,
                taoValue: try BittensorApiDecimal.decimal(point.reportedValueTao),
                usdValue: try BittensorApiDecimal.decimal(point.reportedValueUsd),
                isCompleted: point.completed
            )
        } catch {
            throw SubtensorPortfolioHistoryServiceError.invalidResponse("value")
        }
    }
}
