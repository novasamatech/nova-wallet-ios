import Foundation
import Operation_iOS
import SubstrateSdk

protocol XcmTransactServiceProtocol {
    func transferAndWaitArrivalWrapper(
        _ transferRequest: XcmTransferRequest,
        destinationChainAsset: ChainAsset,
        xcmTransfers: XcmTransfers,
        signer: SigningWrapperProtocol
    ) -> CompoundOperationWrapper<Balance>
}

final class XcmTransactService {
    let chainRegistry: ChainRegistryProtocol
    let transferService: XcmTransferServiceProtocol
    let workingQueue: DispatchQueue
    let operationQueue: OperationQueue

    init(
        chainRegistry: ChainRegistryProtocol,
        transferService: XcmTransferServiceProtocol,
        workingQueue: DispatchQueue,
        operationQueue: OperationQueue
    ) {
        self.chainRegistry = chainRegistry
        self.transferService = transferService
        self.workingQueue = workingQueue
        self.operationQueue = operationQueue
    }
}

extension XcmTransactService: XcmTransactServiceProtocol {
    func transferAndWaitArrivalWrapper(
        _ transferRequest: XcmTransferRequest,
        destinationChainAsset _: ChainAsset,
        xcmTransfers: XcmTransfers,
        signer: SigningWrapperProtocol
    ) -> CompoundOperationWrapper<Balance> {
        let submittionOperation = AsyncClosureOperation<XcmSubmitExtrinsic> { completion in
            self.transferService.submit(
                request: transferRequest,
                xcmTransfers: xcmTransfers,
                signer: signer,
                runningIn: self.workingQueue
            ) { result in
                completion(result)
            }
        }

        return .createWithResult(0)
    }
}
