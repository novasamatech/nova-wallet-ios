import Foundation
import Operation_iOS

final class SubtensorRankingViewService {
    let recommendationService: SubtensorRecommendationServiceProtocol
    let logger: LoggerProtocol

    init(
        recommendationService: SubtensorRecommendationServiceProtocol,
        logger: LoggerProtocol = Logger.shared
    ) {
        self.recommendationService = recommendationService
        self.logger = logger
    }
}

extension SubtensorRankingViewService: SubtensorRankingViewServiceProtocol {
    func createRankingViewWrapper() -> CompoundOperationWrapper<SubtensorRankedSubnets?> {
        let rankedWrapper = recommendationService.createRankedSubnetsWrapper()
        let logger = logger

        let viewOperation = ClosureOperation<SubtensorRankedSubnets?> {
            do {
                return try rankedWrapper.targetOperation.extractNoCancellableResultData()
            } catch {
                logger.warning("Subtensor ranking view unavailable: \(error)")

                return nil
            }
        }

        viewOperation.addDependency(rankedWrapper.targetOperation)

        return rankedWrapper.insertingTail(operation: viewOperation)
    }
}
