import Foundation
import BigInt
import Operation_iOS

struct SwapCommissionResult {
    let builderClosure: ExtrinsicBuilderClosure
    let commissionAmount: Balance
}

enum NovaSwapCommissionClosureFactory {
    enum CommissionError: Error {
        case unsupportedAssetTypeForCommission
    }

    static func createCommissionWrapper(
        outputChainAsset: ChainAsset,
        amountOut: Balance,
        slippage: BigRational,
        runtimeProvider: RuntimeCodingServiceProtocol
    ) -> CompoundOperationWrapper<SwapCommissionResult?> {
        guard outputChainAsset.chain.hasSwapHydra else {
            return .createWithResult(nil)
        }

        // Calculate fee from minAmountOut (post-slippage) to guarantee the transfer
        // never fails due to slippage reducing the actual swap output
        let minAmountOut = amountOut - slippage.mul(value: amountOut)
        let commissionAmount = HydraConstants.novaSwapFeeAmount(from: minAmountOut)

        guard commissionAmount > 0 else {
            return .createWithResult(nil)
        }

        let coderFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()

        let buildClosureOperation = ClosureOperation<SwapCommissionResult?> {
            let codingFactory = try coderFactoryOperation.extractNoCancellableResultData()
            let storageInfo = try AssetStorageInfo.extract(
                from: outputChainAsset.asset,
                codingFactory: codingFactory
            )

            let callFactory = SubstrateCallFactory()
            let feeAccountId = HydraConstants.novaFeeAccountId

            let closure: ExtrinsicBuilderClosure = { builder in
                switch storageInfo {
                case .native:
                    let call = callFactory.nativeTransfer(
                        to: feeAccountId,
                        amount: commissionAmount,
                        callPath: .transferKeepAlive
                    )
                    return try builder.adding(call: call)
                case let .orml(info), let .ormlHydrationEvm(info):
                    let call = callFactory.ormlTransfer(
                        in: info.module,
                        currencyId: info.currencyId,
                        receiverId: feeAccountId,
                        amount: commissionAmount
                    )
                    return try builder.adding(call: call)
                default:
                    throw CommissionError.unsupportedAssetTypeForCommission
                }
            }

            return SwapCommissionResult(
                builderClosure: closure,
                commissionAmount: commissionAmount
            )
        }

        buildClosureOperation.addDependency(coderFactoryOperation)

        return CompoundOperationWrapper(
            targetOperation: buildClosureOperation,
            dependencies: [coderFactoryOperation]
        )
    }

    /// Shared helper that resolves the commission for a swap model.
    /// Calls completion with the result (nil if not a Hydra swap or resolution fails).
    static func resolveCommission(
        for model: SwapExecutionModel,
        chainRegistry: ChainRegistryProtocol,
        operationQueue: OperationQueue,
        callbackQueue: DispatchQueue = .main,
        logger: LoggerProtocol? = nil,
        completion: @escaping (SwapCommissionResult?) -> Void
    ) {
        guard let hydraSwapOp = model.quote.hydraSwapOperation,
              let runtimeProvider = chainRegistry.getRuntimeProvider(
                  for: hydraSwapOp.assetOut.chain.chainId
              ) else {
            completion(nil)
            return
        }

        let wrapper = createCommissionWrapper(
            outputChainAsset: hydraSwapOp.assetOut,
            amountOut: hydraSwapOp.amountOut,
            slippage: model.fee.slippage,
            runtimeProvider: runtimeProvider
        )

        wrapper.targetOperation.completionBlock = {
            callbackQueue.async {
                do {
                    let result = try wrapper.targetOperation.extractNoCancellableResultData()
                    completion(result)
                } catch {
                    logger?.warning("Failed to construct Nova commission: \(error)")
                    completion(nil)
                }
            }
        }

        operationQueue.addOperations(wrapper.allOperations, waitUntilFinished: false)
    }
}
