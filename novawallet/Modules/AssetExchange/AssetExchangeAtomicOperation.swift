import Foundation
import Operation_iOS

protocol AssetExchangeAtomicOperationProtocol {
    func executeWrapper(for amountClosure: () throws -> Balance) -> CompoundOperationWrapper<Balance>
    func estimateFee() -> CompoundOperationWrapper<Balance>
}
