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

/// Protocol for atomic operations that support bundling extra extrinsic calls (e.g., commission transfers)
protocol BundleableAtomicSwapOperation: AssetExchangeAtomicOperationProtocol {
    func executeWrapper(
        for swapLimit: AssetExchangeSwapLimit,
        bundleExtraActions: ExtrinsicBuilderClosure?
    ) -> CompoundOperationWrapper<Balance>

    func submitWrapper(
        for swapLimit: AssetExchangeSwapLimit,
        bundleExtraActions: ExtrinsicBuilderClosure?
    ) -> CompoundOperationWrapper<ExtrinsicSubmittedModel>

    func estimateFee(
        bundleExtraActions: ExtrinsicBuilderClosure?
    ) -> CompoundOperationWrapper<AssetExchangeOperationFee>
}
