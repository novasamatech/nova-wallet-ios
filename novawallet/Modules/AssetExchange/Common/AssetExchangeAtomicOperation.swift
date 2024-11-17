import Foundation
import Operation_iOS

protocol AssetExchangeAtomicOperationProtocol {
    var swapLimit: AssetExchangeSwapLimit { get }

    func executeWrapper(for swapLimit: AssetExchangeSwapLimit) -> CompoundOperationWrapper<Balance>
    func estimateFee() -> CompoundOperationWrapper<AssetExchangeOperationFee>

    func requiredAmountToGetAmountOut(
        _ amountOutClosure: @escaping () throws -> Balance
    ) -> CompoundOperationWrapper<Balance>

    func estimatedExecutionTimeWrapper() -> CompoundOperationWrapper<TimeInterval>
}
