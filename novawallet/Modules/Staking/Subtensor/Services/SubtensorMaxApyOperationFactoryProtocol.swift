import Foundation
import Operation_iOS

protocol SubtensorMaxApyOperationFactoryProtocol: AnyObject {
    func createMaxApyWrapper() -> CompoundOperationWrapper<[UInt16: Decimal]>
}
