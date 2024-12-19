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
    let logger: LoggerProtocol

    init(
        chainRegistry: ChainRegistryProtocol,
        transferService: XcmTransferServiceProtocol,
        workingQueue: DispatchQueue,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.chainRegistry = chainRegistry
        self.transferService = transferService
        self.workingQueue = workingQueue
        self.operationQueue = operationQueue
        self.logger = logger
    }
}

extension XcmTransactService: XcmTransactServiceProtocol {
    func transferAndWaitArrivalWrapper(
        _ transferRequest: XcmTransferRequest,
        destinationChainAsset: ChainAsset,
        xcmTransfers: XcmTransfers,
        signer: SigningWrapperProtocol
    ) -> CompoundOperationWrapper<Balance> {
        do {
            let destinationChainId = destinationChainAsset.chain.chainId
            let connection = try chainRegistry.getConnectionOrError(for: destinationChainId)
            let runtimeProvider = try chainRegistry.getRuntimeProviderOrError(for: destinationChainId)

            let monitoringService = XcmDepositMonitoringService(
                accountId: transferRequest.unweighted.destination.accountId,
                chainAsset: destinationChainAsset,
                connection: connection,
                runtimeProvider: runtimeProvider,
                operationQueue: operationQueue,
                workingQueue: workingQueue,
                logger: logger
            )

            let monitoringWrapper = monitoringService.useMonitoringWrapper()

            let submittionOperation = AsyncClosureOperation<XcmSubmitExtrinsic> { completion in
                self.transferService.submit(
                    request: transferRequest,
                    xcmTransfers: xcmTransfers,
                    signer: signer,
                    runningIn: self.workingQueue
                ) { result in
                    // cancel monitoring in case transaction submission failed
                    if case .failure = result {
                        monitoringWrapper.cancel()
                    }

                    completion(result)
                }
            }

            let mappingOperation = ClosureOperation<Balance> {
                _ = try submittionOperation.extractNoCancellableResultData()

                let arrivedAmount = try monitoringWrapper.targetOperation.extractNoCancellableResultData()

                self.logger.debug("Arrived amount: \(String(arrivedAmount))")

                return arrivedAmount
            }

            mappingOperation.addDependency(monitoringWrapper.targetOperation)
            mappingOperation.addDependency(submittionOperation)

            let dependencies = monitoringWrapper.allOperations + [submittionOperation]

            return CompoundOperationWrapper(targetOperation: mappingOperation, dependencies: dependencies)
        } catch {
            return .createWithError(error)
        }
    }
}
