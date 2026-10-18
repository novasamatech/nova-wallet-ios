import Foundation
import Operation_iOS

protocol SubtensorSubnetMarketsServiceProtocol: AnyObject {
    func createMarketsWrapper() -> CompoundOperationWrapper<SubtensorSubnetMarkets>
}
