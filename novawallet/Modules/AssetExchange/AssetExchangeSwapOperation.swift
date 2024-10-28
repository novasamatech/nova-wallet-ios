import Foundation
import Operation_iOS

protocol AssetExchangeOperationProtocol {
    func executeWrapper(for amountClosure: () throws -> Balance?) -> CompoundOperationWrapper<Balance>
}
