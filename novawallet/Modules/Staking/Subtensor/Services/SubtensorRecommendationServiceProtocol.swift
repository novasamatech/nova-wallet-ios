import Foundation
import Operation_iOS

protocol SubtensorRecommendationServiceProtocol: AnyObject {
    func createRecommendedValidatorsWrapper(
        for subnet: SubtensorSubnetRef
    ) -> CompoundOperationWrapper<SubtensorRecommendedValidators>

    func createRankedSubnetsWrapper() -> CompoundOperationWrapper<SubtensorRankedSubnets>

    func cachedRankedSubnets() -> HTTPCachePeek<SubtensorRankedSubnets>
}
