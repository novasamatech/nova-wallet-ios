import Foundation
import Operation_iOS

final class CrosschainExchangeAtomicOperation {
    let wallet: MetaAccountModel
    let chainRegistry: ChainRegistryProtocol
    let signingWrapperFactory: SigningWrapperFactoryProtocol
    let xcmService: XcmTransferServiceProtocol
    let resolutionFactory: XcmTransferResolutionFactoryProtocol
    let xcmTransfers: XcmTransfers
    let edge: any AssetExchangableGraphEdge
    let operationQueue: OperationQueue
    let workingQueue: DispatchQueue

    init(
        wallet: MetaAccountModel,
        edge: any AssetExchangableGraphEdge,
        chainRegistry: ChainRegistryProtocol,
        xcmService: XcmTransferServiceProtocol,
        resolutionFactory: XcmTransferResolutionFactoryProtocol,
        signingWrapperFactory: SigningWrapperFactoryProtocol,
        xcmTransfers: XcmTransfers,
        operationQueue: OperationQueue,
        workingQueue: DispatchQueue = .global()
    ) {
        self.wallet = wallet
        self.signingWrapperFactory = signingWrapperFactory
        self.chainRegistry = chainRegistry
        self.edge = edge
        self.xcmService = xcmService
        self.resolutionFactory = resolutionFactory
        self.xcmTransfers = xcmTransfers
        self.operationQueue = operationQueue
        self.workingQueue = workingQueue
    }

    private func createXcmPartiesResolutionWrapper(
        dependingOn selectedAccountOperation: BaseOperation<MetaChainAccountResponse>
    ) -> CompoundOperationWrapper<XcmTransferParties> {
        OperationCombiningService<XcmTransferParties>.compoundNonOptionalWrapper(
            operationManager: OperationManager(operationQueue: operationQueue)
        ) {
            let accountId = try selectedAccountOperation.extractNoCancellableResultData().chainAccount.accountId

            return self.resolutionFactory.createResolutionWrapper(
                for: self.edge.origin,
                transferDestinationId: .init(
                    chainId: self.edge.destination.chainId,
                    accountId: accountId
                ),
                xcmTransfers: self.xcmTransfers
            )
        }
    }

    private func createFeeFetchWrapper(
        dependingOn resolutionOperation: BaseOperation<XcmTransferParties>,
        amountClosure: @escaping () throws -> Balance
    ) -> CompoundOperationWrapper<XcmFeeModelProtocol> {
        OperationCombiningService<XcmFeeModelProtocol>.compoundNonOptionalWrapper(
            operationManager: OperationManager(operationQueue: operationQueue)
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
                self.xcmService.estimateCrossChainFee(
                    request: request,
                    xcmTransfers: self.xcmTransfers,
                    runningIn: self.workingQueue
                ) { result in
                    completion(result)
                }
            }

            return CompoundOperationWrapper(targetOperation: feeOperation)
        }
    }

    private func createSubmitWrapper(
        dependingOn signerOperation: BaseOperation<SigningWrapperProtocol>,
        resolutionOperation: BaseOperation<XcmTransferParties>,
        feeOperation: BaseOperation<XcmFeeModelProtocol>,
        amountClosure: @escaping () throws -> Balance
    ) -> CompoundOperationWrapper<XcmSubmitExtrinsic> {
        OperationCombiningService<XcmSubmitExtrinsic>.compoundNonOptionalWrapper(
            operationManager: OperationManager(operationQueue: operationQueue)
        ) {
            let transferParties = try resolutionOperation.extractNoCancellableResultData()
            let fee = try feeOperation.extractNoCancellableResultData()
            let amount = try amountClosure()
            let signer = try signerOperation.extractNoCancellableResultData()

            let operation = AsyncClosureOperation<XcmSubmitExtrinsic> { completion in
                self.xcmService.submit(
                    request: .init(
                        unweighted: .init(
                            origin: transferParties.origin,
                            destination: transferParties.destination,
                            reserve: transferParties.reserve,
                            amount: amount
                        ),
                        maxWeight: fee.weightLimit
                    ),
                    xcmTransfers: self.xcmTransfers,
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
        let selectedAccountWrapper = wallet.fetchChainAccountWrapper(
            for: edge.origin.chainId,
            using: chainRegistry
        )

        let signerFetchWrapper = signingWrapperFactory.createSigningOperationWrapper(
            dependingOn: { try selectedAccountWrapper.targetOperation.extractNoCancellableResultData() },
            operationQueue: operationQueue
        )

        signerFetchWrapper.addDependency(wrapper: selectedAccountWrapper)

        let resolutionWrapper = createXcmPartiesResolutionWrapper(
            dependingOn: selectedAccountWrapper.targetOperation
        )

        let feeWrapper = createFeeFetchWrapper(
            dependingOn: resolutionWrapper.targetOperation,
            amountClosure: amountClosure
        )

        feeWrapper.addDependency(wrapper: resolutionWrapper)

        let submitWrapper = createSubmitWrapper(
            dependingOn: signerFetchWrapper.targetOperation,
            resolutionOperation: resolutionWrapper.targetOperation,
            feeOperation: feeWrapper.targetOperation,
            amountClosure: amountClosure
        )

        submitWrapper.addDependency(wrapper: signerFetchWrapper)
        submitWrapper.addDependency(wrapper: feeWrapper)

        // TODO: Replace with monitoring
        let mappingOperation = ClosureOperation<Balance> {
            _ = try submitWrapper.targetOperation.extractNoCancellableResultData()

            return 0
        }

        mappingOperation.addDependency(submitWrapper.targetOperation)

        return submitWrapper
            .insertingHead(operations: feeWrapper.allOperations)
            .insertingHead(operations: resolutionWrapper.allOperations)
            .insertingHead(operations: signerFetchWrapper.allOperations)
            .insertingHead(operations: selectedAccountWrapper.allOperations)
            .insertingTail(operation: mappingOperation)
    }

    func estimateFee() -> CompoundOperationWrapper<Balance> {
        let selectedAccountWrapper = wallet.fetchChainAccountWrapper(
            for: edge.origin.chainId,
            using: chainRegistry
        )

        let resolutionWrapper = createXcmPartiesResolutionWrapper(
            dependingOn: selectedAccountWrapper.targetOperation
        )

        resolutionWrapper.addDependency(wrapper: selectedAccountWrapper)

        let feeWrapper = createFeeFetchWrapper(
            dependingOn: resolutionWrapper.targetOperation,
            amountClosure: { 0 }
        )

        feeWrapper.addDependency(wrapper: resolutionWrapper)

        let mappingOperation = ClosureOperation<Balance> {
            let fee = try feeWrapper.targetOperation.extractNoCancellableResultData()

            return fee.senderPart
        }

        mappingOperation.addDependency(feeWrapper.targetOperation)

        return feeWrapper
            .insertingHead(operations: resolutionWrapper.allOperations)
            .insertingHead(operations: selectedAccountWrapper.allOperations)
            .insertingTail(operation: mappingOperation)
    }
}
