import Foundation
import Operation_iOS

protocol XcmTransferVerifying {
    func createVerificationWrapper(
        for request: XcmUnweightedTransferRequest,
        callOrigin: RuntimeCallOrigin,
        callClosure: @escaping () throws -> RuntimeCallCollecting
    ) -> CompoundOperationWrapper<Void>
}

enum XcmTransferVerifierError: Error {
    case verificationFailed(Error)
}

final class XcmTransferVerifier {
    let chainRegistry: ChainRegistryProtocol
    let dryRunner: XcmTransferDryRunning

    init(
        chainRegistry: ChainRegistryProtocol,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.chainRegistry = chainRegistry

        dryRunner = XcmTransferDryRunner(
            chainRegistry: chainRegistry,
            dryRunOperationFactory: DryRunOperationFactory(
                chainRegistry: chainRegistry,
                operationQueue: operationQueue
            ),
            palletMetadataQueryFactory: XcmPalletMetadataQueryFactory(),
            operationQueue: operationQueue,
            logger: logger
        )
    }
}

extension XcmTransferVerifier: XcmTransferVerifying {
    func createVerificationWrapper(
        for request: XcmUnweightedTransferRequest,
        callOrigin: RuntimeCallOrigin,
        callClosure: @escaping () throws -> RuntimeCallCollecting
    ) -> CompoundOperationWrapper<Void> {
        do {
            let runtimeProvider = try chainRegistry.getRuntimeProviderOrError(
                for: request.originChain.chainId
            )

            let coderFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()

            let paramsOperation = ClosureOperation<XcmTransferDryRunParams> {
                let callCollecting = try callClosure()
                let codingFactory = try coderFactoryOperation.extractNoCancellableResultData()

                let call = try callCollecting.toAnyRuntimeCall(with: codingFactory.createRuntimeJsonContext())

                return XcmTransferDryRunParams(
                    callOrigin: callOrigin,
                    call: call,
                    amountToSend: request.amount
                )
            }

            paramsOperation.addDependency(coderFactoryOperation)

            let dryRunWrapper = dryRunner.createDryRunWrapper(
                for: request,
                paramsClosure: {
                    try paramsOperation.extractNoCancellableResultData()
                }
            )

            dryRunWrapper.addDependency(operations: [paramsOperation])

            let mappingOperation = ClosureOperation<Void> {
                do {
                    _ = try dryRunWrapper.targetOperation.extractNoCancellableResultData()
                } catch {
                    throw XcmTransferVerifierError.verificationFailed(error)
                }
            }

            mappingOperation.addDependency(dryRunWrapper.targetOperation)

            return dryRunWrapper
                .insertingHead(operations: [coderFactoryOperation, paramsOperation])
                .insertingTail(operation: mappingOperation)
        } catch {
            return .createWithError(error)
        }
    }
}
