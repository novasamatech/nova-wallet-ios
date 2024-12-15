import Foundation
import Operation_iOS

protocol GraphQuotableEdge: GraphWeightableEdgeProtocol where Node == ChainAssetId {
    func quote(amount: Balance, direction: AssetConversion.Direction) -> CompoundOperationWrapper<Balance>
}
