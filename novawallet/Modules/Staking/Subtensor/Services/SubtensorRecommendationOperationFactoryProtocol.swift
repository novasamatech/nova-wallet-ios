import Foundation
import Operation_iOS

struct SubtensorValidatorListVerification {
    let takes: [AccountId: Decimal]
    let statuses: [AccountId: SubtensorValidatorChainStatus]
    let recommended: Result<Set<AccountId>, Error>
}

protocol SubtensorRecommendationOperationFactoryProtocol: AnyObject {
    func createRecommendedValidatorsWrapper(
        for subnet: SubtensorSubnetRef
    ) -> CompoundOperationWrapper<SubtensorRecommendedValidators>

    func createListVerificationWrapper(
        for subnet: SubtensorSubnetRef,
        listedHotkeys: [AccountId]
    ) -> CompoundOperationWrapper<SubtensorValidatorListVerification>

    func createRankedSubnetsWrapper() -> CompoundOperationWrapper<SubtensorRankedSubnets>

    func cachedRankedSubnets() -> HTTPCachePeek<SubtensorRankedSubnets>
}
