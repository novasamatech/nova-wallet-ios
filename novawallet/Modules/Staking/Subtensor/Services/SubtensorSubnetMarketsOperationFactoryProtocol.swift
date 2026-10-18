import Foundation
import Operation_iOS

protocol SubtensorSubnetMarketsOperationFactoryProtocol: AnyObject {
    func createMarketsWrapper() -> CompoundOperationWrapper<SubtensorSubnetMarkets>
}
