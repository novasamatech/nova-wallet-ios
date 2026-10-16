import Foundation
import Operation_iOS

protocol SubtensorMaxApyProviderProtocol: AnyObject {
    func createMaxApyWrapper() -> CompoundOperationWrapper<[UInt16: Decimal]>
}
