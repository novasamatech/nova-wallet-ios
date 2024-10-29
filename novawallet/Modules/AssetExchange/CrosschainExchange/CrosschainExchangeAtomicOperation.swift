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

    init(
        wallet: MetaAccountModel,
        edge: any AssetExchangableGraphEdge,
        chainRegistry: ChainRegistryProtocol,
        xcmService: XcmTransferServiceProtocol,
        resolutionFactory: XcmTransferResolutionFactoryProtocol,
        signingWrapperFactory: SigningWrapperFactoryProtocol,
        xcmTransfers: XcmTransfers,
        operationQueue: OperationQueue
    ) {
        self.wallet = wallet
        self.signingWrapperFactory = signingWrapperFactory
        self.chainRegistry = chainRegistry
        self.edge = edge
        self.xcmService = xcmService
        self.resolutionFactory = resolutionFactory
        self.xcmTransfers = xcmTransfers
        self.operationQueue = operationQueue
    }
    
    private func origingAccountWrapper(
        from wallet: MetaAccountModel
    ) -> CompoundOperationWrapper<ChainAccountResponse> {
        let chainWrapper = chainRegistry.asyncWaitChainWrapper(for: edge.origin.chainId)
        
        let selectedAccountOperation = ClosureOperation<ChainAccountResponse> {
            let chain = try chainWrapper.targetOperation.extractNoCancellableResultData()
            
            guard let 
        }
    }
}

extension CrosschainExchangeAtomicOperation: AssetExchangeAtomicOperationProtocol {
    func executeWrapper(for amountClosure: () throws -> Balance) -> CompoundOperationWrapper<Balance> {
        let selectedAccountWrapper = wallet.fetchChainAccountWrapper(
            for: edge.origin.chainId,
            using: chainRegistry
        )
        
        let signingOperationWrapper = signingWrapperFactory.createSigningOperationWrapper(
            dependingOn: { try selectedAccountWrapper.targetOperation.extractNoCancellableResultData() },
            operationQueue: operationQueue
        )
        
        signingOperationWrapper.addDependency(wrapper: selectedAccountWrapper)
        
        
        let submitWrapper = xcmService.submit(
            request: .ini,
            xcmTransfers: xcmTransfers,
            signer: <#T##any SigningWrapperProtocol#>, runningIn: <#T##DispatchQueue#>, completion: <#T##XcmExtrinsicSubmitClosure##XcmExtrinsicSubmitClosure##(XcmSubmitExtrinsicResult) -> Void#>)
    }

    func estimateFee() -> CompoundOperationWrapper<Balance> {
        let resolutionWrapper = resolutionFactory.createResolutionWrapper(
            for: edge.origin,
            transferDestinationId: .init(
                chainId: edge.destination.chainId,
                accountId: AccountId.zeroAccountId(of: 32)
            ),
            xcmTransfers: xcmTransfers
        )

        let feeWrapper = OperationCombiningService.compoundNonOptionalWrapper(
            operationManager: OperationManager(operationQueue: operationQueue)
        ) {
            let transferParties = try resolutionWrapper.targetOperation.extractNoCancellableResultData()

            let request = XcmUnweightedTransferRequest(
                origin: transferParties.origin,
                destination: transferParties.destination,
                reserve: transferParties.reserve,
                amount: 0
            )

            let feeOperation = AsyncClosureOperation<XcmFeeModelProtocol> { completion in
                self.xcmService.estimateCrossChainFee(
                    request: request,
                    xcmTransfers: self.xcmTransfers,
                    runningIn: .global()
                ) { result in
                    completion(result)
                }
            }

            return CompoundOperationWrapper(targetOperation: feeOperation)
        }

        feeWrapper.addDependency(wrapper: resolutionWrapper)

        let mappingOperation = ClosureOperation<Balance> {
            let fee = try feeWrapper.targetOperation.extractNoCancellableResultData()

            return fee.senderPart
        }

        mappingOperation.addDependency(feeWrapper.targetOperation)

        return feeWrapper
            .insertingHead(operations: resolutionWrapper.allOperations)
            .insertingTail(operation: mappingOperation)
    }
}
