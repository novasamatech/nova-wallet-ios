import Foundation
import Operation_iOS

protocol AssetExchangeAtomicOperationProtocol {
    func executeWrapper(for amountClosure: @escaping () throws -> Balance) -> CompoundOperationWrapper<Balance>
    func estimateFee() -> CompoundOperationWrapper<AssetExchangeOperationFee>
}
