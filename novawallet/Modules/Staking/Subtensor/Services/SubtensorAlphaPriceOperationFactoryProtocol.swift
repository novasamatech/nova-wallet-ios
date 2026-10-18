import Foundation
import Operation_iOS

protocol SubtensorAlphaPriceOperationFactoryProtocol: AnyObject {
    func createPricesWrapper(for netuids: Set<UInt16>) -> CompoundOperationWrapper<SubtensorAlphaPrices>

    func cachedPrices() -> SubtensorAlphaPrices?
}
