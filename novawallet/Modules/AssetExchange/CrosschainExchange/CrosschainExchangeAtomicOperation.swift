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
        for destinationAccount: ChainAccountResponse
    ) -> CompoundOperationWrapper<XcmTransferParties> {
        host.resolutionFactory.createResolutionWrapper(
            for: edge.origin,
            transferDestinationId: .init(
                chainId: edge.destination.chainId,
                accountId: destinationAccount.accountId
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
        for originAccount: ChainAccountResponse,
        destinationAsset: ChainAsset,
        resolutionOperation: BaseOperation<XcmTransferParties>,
        feeOperation: BaseOperation<XcmFeeModelProtocol>,
        amountClosure: @escaping () throws -> Balance
    ) -> CompoundOperationWrapper<Balance> {
        OperationCombiningService<Balance>.compoundNonOptionalWrapper(
            operationQueue: host.operationQueue
        ) {
            let transferParties = try resolutionOperation.extractNoCancellableResultData()
            let fee = try feeOperation.extractNoCancellableResultData()
            let amount = try amountClosure()

            let signer = self.host.signingWrapperFactory.createSigningWrapper(
                for: originAccount.metaId,
                accountResponse: originAccount
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

            let transactService = XcmTransactService(
                chainRegistry: self.host.chainRegistry,
                transferService: self.host.xcmService,
                workingQueue: self.workingQueue,
                operationQueue: self.host.operationQueue,
                logger: self.host.logger
            )

            return transactService.transferAndWaitArrivalWrapper(
                transferRequest,
                destinationChainAsset: destinationAsset,
                xcmTransfers: self.host.xcmTransfers,
                signer: signer
            )
        }
    }
}

extension CrosschainExchangeAtomicOperation: AssetExchangeAtomicOperationProtocol {
    func executeWrapper(for swapLimit: AssetExchangeSwapLimit) -> CompoundOperationWrapper<Balance> {
        guard
            let originChain = host.allChains[edge.origin.chainId],
            let destinationChain = host.allChains[edge.destination.chainId],
            let destinationAsset = destinationChain.chainAsset(for: edge.destination.assetId),
            let originAccount = host.wallet.fetch(for: originChain.accountRequest()),
            let destinationAccount = host.wallet.fetch(for: destinationChain.accountRequest()) else {
            return .createWithError(ChainAccountFetchingError.accountNotExists)
        }

        let resolutionWrapper = createXcmPartiesResolutionWrapper(for: destinationAccount)

        // TODO: We need only weight from the crosschain fee, probably we can calculate it during submission
        let feeWrapper = createCrosschainFeeFetchWrapper(
            dependingOn: resolutionWrapper.targetOperation,
            amountClosure: { swapLimit.amountIn }
        )

        feeWrapper.addDependency(wrapper: resolutionWrapper)

        let submitWrapper = createSubmitWrapper(
            for: originAccount,
            destinationAsset: destinationAsset,
            resolutionOperation: resolutionWrapper.targetOperation,
            feeOperation: feeWrapper.targetOperation,
            amountClosure: { swapLimit.amountIn }
        )

        submitWrapper.addDependency(wrapper: feeWrapper)

        return submitWrapper
            .insertingHead(operations: feeWrapper.allOperations)
            .insertingHead(operations: resolutionWrapper.allOperations)
    }

    func estimateFee() -> CompoundOperationWrapper<AssetExchangeOperationFee> {
        guard
            let originChain = host.allChains[edge.origin.chainId],
            let originUtilityAsset = originChain.utilityChainAsset(),
            let destinationChain = host.allChains[edge.destination.chainId],
            let destinationAccount = host.wallet.fetch(for: destinationChain.accountRequest()) else {
            return .createWithError(ChainAccountFetchingError.accountNotExists)
        }

        let resolutionWrapper = createXcmPartiesResolutionWrapper(for: destinationAccount)

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
                originUtilityAsset: originUtilityAsset.chainAssetId,
                args: self.operationArgs
            )
        }

        mappingOperation.addDependency(crosschainFeeWrapper.targetOperation)
        mappingOperation.addDependency(originFeeWrapper.targetOperation)

        return originFeeWrapper
            .insertingHead(operations: crosschainFeeWrapper.allOperations)
            .insertingHead(operations: resolutionWrapper.allOperations)
            .insertingTail(operation: mappingOperation)
    }

    func requiredAmountToGetAmountOut(
        _ amountOutClosure: @escaping () throws -> Balance
    ) -> CompoundOperationWrapper<Balance> {
        let operation = ClosureOperation {
            try amountOutClosure()
        }

        return CompoundOperationWrapper(targetOperation: operation)
    }

    var swapLimit: AssetExchangeSwapLimit {
        operationArgs.swapLimit
    }

    func estimatedExecutionTimeWrapper() -> CompoundOperationWrapper<TimeInterval> {
        guard
            let destinationChain = host.allChains[edge.destination.chainId],
            let destinationAccount = host.wallet.fetch(for: destinationChain.accountRequest()) else {
            return .createWithError(ChainAccountFetchingError.accountNotExists)
        }

        let resolutionWrapper = createXcmPartiesResolutionWrapper(for: destinationAccount)

        let estimationTimeWrapper = OperationCombiningService<TimeInterval>.compoundNonOptionalWrapper(
            operationQueue: host.operationQueue
        ) {
            let partiesResolution = try resolutionWrapper.targetOperation.extractNoCancellableResultData()

            let originChain = partiesResolution.origin.chain
            let destinationChain = partiesResolution.destination.chain
            let reserveChain = partiesResolution.reserve.chain

            let relaychainId = [originChain, destinationChain, reserveChain]
                .compactMap(\.parentId)
                .first ?? originChain.chainId

            var participatingChains: [ChainModel.Id] = [originChain.chainId]

            if originChain.chainId != reserveChain.chainId {
                participatingChains.append(reserveChain.chainId)

                if !originChain.isRelaychain, !reserveChain.isRelaychain {
                    participatingChains.append(relaychainId)
                }
            }

            if reserveChain.chainId != destinationChain.chainId {
                participatingChains.append(destinationChain.chainId)

                if !reserveChain.isRelaychain, !destinationChain.isRelaychain {
                    participatingChains.append(relaychainId)
                }
            }

            guard !participatingChains.isEmpty else {
                return .createWithResult(0)
            }

            return self.host.executionTimeEstimator.totalTimeWrapper(for: participatingChains)
        }

        estimationTimeWrapper.addDependency(wrapper: resolutionWrapper)

        return estimationTimeWrapper.insertingHead(operations: resolutionWrapper.allOperations)
    }
}
