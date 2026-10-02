import Foundation
import Operation_iOS

protocol SubtensorMaxApyProviderProtocol: AnyObject {
    func createMaxApyWrapper() -> CompoundOperationWrapper<Decimal?>

    func cachedMaxApy() -> HTTPCachePeek<Decimal?>
}
