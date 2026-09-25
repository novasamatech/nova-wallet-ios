import Foundation
import Operation_iOS

protocol SubtensorDiscoveryServiceProtocol: AnyObject {
    func createStrategyOffersWrapper() -> CompoundOperationWrapper<[SubtensorStrategyOffer]>

    func createPickCandidatesWrapper(
        for kind: SubtensorStrategyKind
    ) -> CompoundOperationWrapper<SubtensorPickCandidates>
}
