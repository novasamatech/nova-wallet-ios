import Foundation
import Operation_iOS

protocol SubtensorRecommendationServiceProtocol: AnyObject {
    func createVerifiedRecommendationsWrapper() -> CompoundOperationWrapper<SubtensorVerifiedRecommendations>

    func createRankedSubnetsWrapper() -> CompoundOperationWrapper<SubtensorRankedSubnets>

    func cachedRankedSubnets() -> HTTPCachePeek<SubtensorRankedSubnets>

    func createClientGatesWrapper() -> CompoundOperationWrapper<SubtensorClientGates>

    func cachedClientGates() -> HTTPCachePeek<SubtensorClientGates>
}
