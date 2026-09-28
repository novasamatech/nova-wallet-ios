import Foundation
import Operation_iOS

protocol SubtensorRankingViewServiceProtocol: AnyObject {
    func createRankingViewWrapper() -> CompoundOperationWrapper<SubtensorRankedSubnets?>
}
