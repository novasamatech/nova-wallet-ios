import Foundation
import Operation_iOS

final class CrosschainExchangeAtomicOperation {
    let host: CrosschainExchangeHostProtocol
    let operationArgs: AssetExchangeAtomicOperationArgs
    let edge: any AssetExchangableGraphEdge
    let workingQueue: DispatchQueue

    init(
        host: CrosschainExchangeHostProtocol,
        edge: any AssetExchangableGraphEdge,
        operationArgs: AssetExchangeAtomicOperationArgs,
        workingQueue: DispatchQueue = .global()
    ) {
        self.host = host
        self.edge = edge
        self.operationArgs = operationArgs
        self.workingQueue = workingQueue
    }

    private func createXcmPartiesResolutionWrapper(
        for selectedAccount: ChainAccountResponse
    ) -> CompoundOperationWrapper<XcmTransferParties> {
        host.resolutionFactory.createResolutionWrapper(
            for: edge.origin,
            transferDestinationId: .init(
                chainId: edge.destination.chainId,
                accountId: selectedAccount.accountId
            ),
            xcmTransfers: host.xcmTransfers
        )
    }

    private func createOriginFeeFetchWrapper(
        dependingOn resolutionOperation: BaseOperation<XcmTransferParties>,
        feeOperation: BaseOperation<XcmFeeModelProtocol>,
        amountClosure: @escaping () throws -> Balance
    ) -> CompoundOperationWrapper<ExtrinsicFeeProtocol> {
        OperationCombiningService<ExtrinsicFeeProtocol>.compoundNonOptionalWrapper(
            operationQueue: host.operationQueue
        ) {
            let transferParties = try resolutionOperation.extractNoCancellableResultData()
            let crosschainFee = try feeOperation.extractNoCancellableResultData()
            let amount = try amountClosure()

            let unweightedRequest = XcmUnweightedTransferRequest(
                origin: transferParties.origin,
                destination: transferParties.destination,
                reserve: transferParties.reserve,
                amount: amount
            )

            let transferRequest = XcmTransferRequest(
                unweighted: unweightedRequest,
                maxWeight: crosschainFee.weightLimit,
                originFeeAsset: self.operationArgs.feeAsset
            )

            let feeOperation = AsyncClosureOperation<ExtrinsicFeeProtocol> { completion in
                self.host.xcmService.estimateOriginFee(
                    request: transferRequest,
                    xcmTransfers: self.host.xcmTransfers,
                    runningIn: self.workingQueue
                ) { result in
                    completion(result)
                }
            }

            return CompoundOperationWrapper(targetOperation: feeOperation)
        }
    }

    private func createCrosschainFeeFetchWrapper(
        dependingOn resolutionOperation: BaseOperation<XcmTransferParties>,
        amountClosure: @escaping () throws -> Balance
    ) -> CompoundOperationWrapper<XcmFeeModelProtocol> {
        OperationCombiningService<XcmFeeModelProtocol>.compoundNonOptionalWrapper(
            operationQueue: host.operationQueue
        ) {
            let transferParties = try resolutionOperation.extractNoCancellableResultData()
            let amount = try amountClosure()

            let request = XcmUnweightedTransferRequest(
                origin: transferParties.origin,
                destination: transferParties.destination,
                reserve: transferParties.reserve,
                amount: amount
            )

            let feeOperation = AsyncClosureOperation<XcmFeeModelProtocol> { completion in
                self.host.xcmService.estimateCrossChainFee(
                    request: request,
                    xcmTransfers: self.host.xcmTransfers,
                    runningIn: self.workingQueue
                ) { result in
                    completion(result)
                }
            }

            return CompoundOperationWrapper(targetOperation: feeOperation)
        }
    }

    private func createSubmitWrapper(
        for selectedAccount: ChainAccountResponse,
        resolutionOperation: BaseOperation<XcmTransferParties>,
        feeOperation: BaseOperation<XcmFeeModelProtocol>,
        amountClosure: @escaping () throws -> Balance
    ) -> CompoundOperationWrapper<XcmSubmitExtrinsic> {
        OperationCombiningService<XcmSubmitExtrinsic>.compoundNonOptionalWrapper(
            operationQueue: host.operationQueue
        ) {
            let transferParties = try resolutionOperation.extractNoCancellableResultData()
            let fee = try feeOperation.extractNoCancellableResultData()
            let amount = try amountClosure()

            let signer = self.host.signingWrapperFactory.createSigningWrapper(
                for: selectedAccount.metaId,
                accountResponse: selectedAccount
            )

            let unweightedRequest = XcmUnweightedTransferRequest(
                origin: transferParties.origin,
                destination: transferParties.destination,
                reserve: transferParties.reserve,
                amount: amount
            )

            let transferRequest = XcmTransferRequest(
                unweighted: unweightedRequest,
                maxWeight: fee.weightLimit,
                originFeeAsset: self.operationArgs.feeAsset
            )

            let operation = AsyncClosureOperation<XcmSubmitExtrinsic> { completion in
                self.host.xcmService.submit(
                    request: transferRequest,
                    xcmTransfers: self.host.xcmTransfers,
                    signer: signer,
                    runningIn: self.workingQueue
                ) { result in
                    completion(result)
                }
            }

            return CompoundOperationWrapper(targetOperation: operation)
        }
    }
}

extension CrosschainExchangeAtomicOperation: AssetExchangeAtomicOperationProtocol {
    func executeWrapper(for amountClosure: @escaping () throws -> Balance) -> CompoundOperationWrapper<Balance> {
        guard
            let originChain = host.allChains[edge.origin.chainId],
            let selectedAccount = host.wallet.fetch(for: originChain.accountRequest()) else {
            return .createWithError(ChainAccountFetchingError.accountNotExists)
        }

        let resolutionWrapper = createXcmPartiesResolutionWrapper(for: selectedAccount)

        // TODO: We need only weight from the crosschain fee, probably we can calculate it during submission
        let feeWrapper = createCrosschainFeeFetchWrapper(
            dependingOn: resolutionWrapper.targetOperation,
            amountClosure: amountClosure
        )

        feeWrapper.addDependency(wrapper: resolutionWrapper)

        let submitWrapper = createSubmitWrapper(
            for: selectedAccount,
            resolutionOperation: resolutionWrapper.targetOperation,
            feeOperation: feeWrapper.targetOperation,
            amountClosure: amountClosure
        )

        submitWrapper.addDependency(wrapper: feeWrapper)

        // TODO: Replace with monitoring to understand actual amount received
        let mappingOperation = ClosureOperation<Balance> {
            _ = try submitWrapper.targetOperation.extractNoCancellableResultData()

            return self.operationArgs.swapLimit.amountOut
        }

        mappingOperation.addDependency(submitWrapper.targetOperation)

        return submitWrapper
            .insertingHead(operations: feeWrapper.allOperations)
            .insertingHead(operations: resolutionWrapper.allOperations)
            .insertingTail(operation: mappingOperation)
    }

    func estimateFee() -> CompoundOperationWrapper<AssetExchangeOperationFee> {
        guard
            let originChain = host.allChains[edge.origin.chainId],
            let selectedAccount = host.wallet.fetch(for: originChain.accountRequest()) else {
            return .createWithError(ChainAccountFetchingError.accountNotExists)
        }

        let resolutionWrapper = createXcmPartiesResolutionWrapper(for: selectedAccount)

        let crosschainFeeWrapper = createCrosschainFeeFetchWrapper(
            dependingOn: resolutionWrapper.targetOperation,
            amountClosure: { self.operationArgs.swapLimit.amountIn }
        )

        crosschainFeeWrapper.addDependency(wrapper: resolutionWrapper)

        let originFeeWrapper = createOriginFeeFetchWrapper(
            dependingOn: resolutionWrapper.targetOperation,
            feeOperation: crosschainFeeWrapper.targetOperation,
            amountClosure: { self.operationArgs.swapLimit.amountIn }
        )

        originFeeWrapper.addDependency(wrapper: crosschainFeeWrapper)

        let mappingOperation = ClosureOperation<AssetExchangeOperationFee> {
            let originFee = try originFeeWrapper.targetOperation.extractNoCancellableResultData()
            let crosschainFee = try crosschainFeeWrapper.targetOperation.extractNoCancellableResultData()

            return .init(
                crosschainFee: crosschainFee,
                originFee: originFee,
                assetIn: self.edge.origin,
                assetOut: self.edge.destination,
                args: self.operationArgs
            )
        }

        mappingOperation.addDependency(crosschainFeeWrapper.targetOperation)
        mappingOperation.addDependency(originFeeWrapper.targetOperation)

        return crosschainFeeWrapper
            .insertingHead(operations: originFeeWrapper.allOperations)
            .insertingHead(operations: resolutionWrapper.allOperations)
            .insertingTail(operation: mappingOperation)
    }
}
