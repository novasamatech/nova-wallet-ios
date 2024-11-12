import Foundation
import Operation_iOS

protocol AssetExchangeAtomicOperationProtocol {
    var swapLimit: AssetExchangeSwapLimit { get }

    func executeWrapper(for amountClosure: @escaping () throws -> Balance) -> CompoundOperationWrapper<Balance>
    func estimateFee() -> CompoundOperationWrapper<AssetExchangeOperationFee>
}
