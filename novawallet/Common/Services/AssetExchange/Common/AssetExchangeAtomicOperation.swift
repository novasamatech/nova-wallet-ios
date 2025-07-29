import Foundation
import Operation_iOS

protocol AssetExchangeAtomicOperationProtocol {
    var swapLimit: AssetExchangeSwapLimit { get }

    func executeWrapper(for swapLimit: AssetExchangeSwapLimit) -> CompoundOperationWrapper<Balance>

    func submitWrapper(
        for swapLimit: AssetExchangeSwapLimit
    ) -> CompoundOperationWrapper<ExtrinsicSubmittedModel>

    func estimateFee() -> CompoundOperationWrapper<AssetExchangeOperationFee>

    func requiredAmountToGetAmountOut(
        _ amountOutClosure: @escaping () throws -> Balance
    ) -> CompoundOperationWrapper<Balance>
}
