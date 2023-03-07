import Foundation
import SubstrateSdk
import RobinHood
import IrohaCrypto

protocol ExtrinsicServiceProtocol {
    func estimateFee(
        _ closure: @escaping ExtrinsicBuilderClosure,
        runningIn queue: DispatchQueue,
        completion completionClosure: @escaping EstimateFeeClosure
    )

    func estimateFee(
        _ closure: @escaping ExtrinsicBuilderIndexedClosure,
        runningIn queue: DispatchQueue,
        indexes: IndexSet,
        completion completionClosure: @escaping EstimateFeeIndexedClosure
    )

    func estimateFeeWithSplitter(
        _ splitter: ExtrinsicSplitting,
        runningIn queue: DispatchQueue,
        completion completionClosure: @escaping EstimateFeeIndexedClosure
    )

    func submit(
        _ closure: @escaping ExtrinsicBuilderClosure,
        signer: SigningWrapperProtocol,
        runningIn queue: DispatchQueue,
        completion completionClosure: @escaping ExtrinsicSubmitClosure
    )

    func submit(
        _ closure: @escaping ExtrinsicBuilderIndexedClosure,
        signer: SigningWrapperProtocol,
        runningIn queue: DispatchQueue,
        numberOfExtrinsics: Int,
        completion completionClosure: @escaping ExtrinsicSubmitIndexedClosure
    )

    func submitWithTxSplitter(
        _ splitter: ExtrinsicSplitting,
        signer: SigningWrapperProtocol,
        runningIn queue: DispatchQueue,
        completion completionClosure: @escaping ExtrinsicSubmitIndexedClosure
    )

    func submitAndWatch(
        _ closure: @escaping ExtrinsicBuilderClosure,
        signer: SigningWrapperProtocol,
        runningIn queue: DispatchQueue,
        subscriptionIdClosure: @escaping ExtrinsicSubscriptionIdClosure,
        notificationClosure: @escaping ExtrinsicSubscriptionStatusClosure
    )

    func cancelExtrinsicWatch(for identifier: UInt16)

    func buildExtrinsic(
        _ closure: @escaping ExtrinsicBuilderClosure,
        signer: SigningWrapperProtocol,
        runningIn queue: DispatchQueue,
        completion completionClosure: @escaping ExtrinsicSubmitClosure
    )
}

extension ExtrinsicServiceProtocol {
    func estimateFee(
        _ closure: @escaping ExtrinsicBuilderIndexedClosure,
        runningIn queue: DispatchQueue,
        numberOfExtrinsics: Int,
        completion completionClosure: @escaping EstimateFeeIndexedClosure
    ) {
        estimateFee(
            closure,
            runningIn: queue,
            indexes: IndexSet(0 ..< numberOfExtrinsics),
            completion: completionClosure
        )
    }
}

final class ExtrinsicService {
    let operationFactory: ExtrinsicOperationFactoryProtocol
    let operationManager: OperationManagerProtocol

    init(
        accountId: AccountId,
        chain: ChainModel,
        cryptoType: MultiassetCryptoType,
        walletType: MetaAccountModelType,
        runtimeRegistry: RuntimeCodingServiceProtocol,
        engine: JSONRPCEngine,
        operationManager: OperationManagerProtocol
    ) {
        operationFactory = ExtrinsicOperationFactory(
            accountId: accountId,
            chain: chain,
            cryptoType: cryptoType,
            signaturePayloadFormat: walletType.signaturePayloadFormat,
            runtimeRegistry: runtimeRegistry,
            customExtensions: DefaultExtrinsicExtension.extensions,
            engine: engine,
            operationManager: operationManager
        )

        self.operationManager = operationManager
    }

    private func submitAndSubscribe(
        extrinsic: String,
        runningIn queue: DispatchQueue,
        subscriptionIdClosure: @escaping ExtrinsicSubscriptionIdClosure,
        notificationClosure: @escaping ExtrinsicSubscriptionStatusClosure
    ) {
        do {
            let updateClosure: (ExtrinsicSubscriptionUpdate) -> Void = { update in
                let status = update.params.result
                queue.async {
                    notificationClosure(.success(status))
                }
            }

            let failureClosure: (Error, Bool) -> Void = { error, _ in
                DispatchQueue.main.async {
                    notificationClosure(.failure(error))
                }
            }

            let subscriptionId = try operationFactory.connection.subscribe(
                RPCMethod.submitAndWatchExtrinsic,
                params: [extrinsic],
                updateClosure: updateClosure,
                failureClosure: failureClosure
            )

            if !subscriptionIdClosure(subscriptionId) {
                // extrinsic still should be submitted but without subscription
                operationFactory.connection.cancelForIdentifier(subscriptionId)
            }
        } catch {
            notificationClosure(.failure(error))
        }
    }
}

extension ExtrinsicService: ExtrinsicServiceProtocol {
    func estimateFee(
        _ closure: @escaping ExtrinsicBuilderClosure,
        runningIn queue: DispatchQueue,
        completion completionClosure: @escaping EstimateFeeClosure
    ) {
        let wrapper = operationFactory.estimateFeeOperation(closure)

        wrapper.targetOperation.completionBlock = {
            queue.async {
                if let result = wrapper.targetOperation.result {
                    completionClosure(result)
                } else {
                    completionClosure(.failure(BaseOperationError.parentOperationCancelled))
                }
            }
        }

        operationManager.enqueue(operations: wrapper.allOperations, in: .transient)
    }

    func estimateFee(
        _ closure: @escaping ExtrinsicBuilderIndexedClosure,
        runningIn queue: DispatchQueue,
        indexes: IndexSet,
        completion completionClosure: @escaping EstimateFeeIndexedClosure
    ) {
        let wrapper = operationFactory.estimateFeeOperation(closure, indexes: indexes)

        wrapper.targetOperation.completionBlock = {
            queue.async {
                do {
                    let result = try wrapper.targetOperation.extractNoCancellableResultData()
                    completionClosure(result)
                } catch {
                    let result = FeeIndexedExtrinsicResult(
                        builderClosure: closure,
                        error: error,
                        indexes: Array(indexes)
                    )

                    completionClosure(result)
                }
            }
        }

        operationManager.enqueue(operations: wrapper.allOperations, in: .transient)
    }

    func estimateFeeWithSplitter(
        _ splitter: ExtrinsicSplitting,
        runningIn queue: DispatchQueue,
        completion completionClosure: @escaping EstimateFeeIndexedClosure
    ) {
        let extrinsicsWrapper = splitter.buildWrapper(using: operationFactory)

        let feeWrapper = OperationCombiningService.compoundWrapper(operationManager: operationManager) {
            let result = try extrinsicsWrapper.targetOperation.extractNoCancellableResultData()

            return self.operationFactory.estimateFeeOperation(result.closure, numberOfExtrinsics: result.numberOfExtrinsics)
        }

        feeWrapper.addDependency(wrapper: extrinsicsWrapper)

        feeWrapper.targetOperation.completionBlock = {
            queue.async {
                do {
                    if let operationResult = try feeWrapper.targetOperation.extractNoCancellableResultData() {
                        completionClosure(operationResult)
                    } else {
                        throw BaseOperationError.unexpectedDependentResult
                    }
                } catch {
                    let splitterResult = try? extrinsicsWrapper.targetOperation.extractNoCancellableResultData()
                    let numberOfExtrinsics = splitterResult?.numberOfExtrinsics ?? 1
                    let result = FeeIndexedExtrinsicResult(
                        builderClosure: splitterResult?.closure,
                        error: error,
                        indexes: Array(0 ..< numberOfExtrinsics)
                    )

                    completionClosure(result)
                }
            }
        }

        let operations = extrinsicsWrapper.allOperations + feeWrapper.allOperations

        operationManager.enqueue(operations: operations, in: .transient)
    }

    func submit(
        _ closure: @escaping ExtrinsicBuilderClosure,
        signer: SigningWrapperProtocol,
        runningIn queue: DispatchQueue,
        completion completionClosure: @escaping ExtrinsicSubmitClosure
    ) {
        let wrapper = operationFactory.submit(closure, signer: signer)

        wrapper.targetOperation.completionBlock = {
            queue.async {
                if let result = wrapper.targetOperation.result {
                    completionClosure(result)
                } else {
                    completionClosure(.failure(BaseOperationError.parentOperationCancelled))
                }
            }
        }

        operationManager.enqueue(operations: wrapper.allOperations, in: .transient)
    }

    func submitWithTxSplitter(
        _ txSplitter: ExtrinsicSplitting,
        signer: SigningWrapperProtocol,
        runningIn queue: DispatchQueue,
        completion completionClosure: @escaping ExtrinsicSubmitIndexedClosure
    ) {
        let extrinsicsWrapper = txSplitter.buildWrapper(using: operationFactory)

        let submissionWrapper = OperationCombiningService.compoundWrapper(operationManager: operationManager) {
            let result = try extrinsicsWrapper.targetOperation.extractNoCancellableResultData()

            return self.operationFactory.submit(
                result.closure,
                signer: signer,
                numberOfExtrinsics: result.numberOfExtrinsics
            )
        }

        submissionWrapper.addDependency(wrapper: extrinsicsWrapper)

        submissionWrapper.targetOperation.completionBlock = {
            queue.async {
                do {
                    if let operationResult = try submissionWrapper.targetOperation.extractNoCancellableResultData() {
                        completionClosure(operationResult)
                    } else {
                        throw BaseOperationError.unexpectedDependentResult
                    }
                } catch {
                    let splitterResult = try? extrinsicsWrapper.targetOperation.extractNoCancellableResultData()
                    let numberOfExtrinsics = splitterResult?.numberOfExtrinsics ?? 1
                    let result = SubmitIndexedExtrinsicResult(
                        builderClosure: splitterResult?.closure,
                        error: error,
                        indexes: Array(0 ..< numberOfExtrinsics)
                    )

                    completionClosure(result)
                }
            }
        }

        let operations = extrinsicsWrapper.allOperations + submissionWrapper.allOperations

        operationManager.enqueue(operations: operations, in: .transient)
    }

    func submitAndWatch(
        _ closure: @escaping ExtrinsicBuilderClosure,
        signer: SigningWrapperProtocol,
        runningIn queue: DispatchQueue,
        subscriptionIdClosure: @escaping ExtrinsicSubscriptionIdClosure,
        notificationClosure: @escaping ExtrinsicSubscriptionStatusClosure
    ) {
        let extrinsicWrapper = operationFactory.buildExtrinsic(closure, signer: signer)

        extrinsicWrapper.targetOperation.completionBlock = { [weak self] in
            queue.async {
                do {
                    let extrinsic = try extrinsicWrapper.targetOperation.extractNoCancellableResultData()
                    self?.submitAndSubscribe(
                        extrinsic: extrinsic,
                        runningIn: queue,
                        subscriptionIdClosure: subscriptionIdClosure,
                        notificationClosure: notificationClosure
                    )
                } catch {
                    notificationClosure(.failure(error))
                }
            }
        }

        operationManager.enqueue(operations: extrinsicWrapper.allOperations, in: .transient)
    }

    func cancelExtrinsicWatch(for identifier: UInt16) {
        operationFactory.connection.cancelForIdentifier(identifier)
    }

    func buildExtrinsic(
        _ closure: @escaping ExtrinsicBuilderClosure,
        signer: SigningWrapperProtocol,
        runningIn queue: DispatchQueue,
        completion completionClosure: @escaping (Result<String, Error>) -> Void
    ) {
        let extrinsicOperation = operationFactory.buildExtrinsic(closure, signer: signer)

        extrinsicOperation.targetOperation.completionBlock = {
            queue.async {
                if let result = extrinsicOperation.targetOperation.result, let params = try? result.get() {
                    completionClosure(.success(params))
                } else {
                    completionClosure(.failure(BaseOperationError.parentOperationCancelled))
                }
            }
        }

        operationManager.enqueue(operations: extrinsicOperation.allOperations, in: .transient)
    }

    func submit(
        _ closure: @escaping ExtrinsicBuilderIndexedClosure,
        signer: SigningWrapperProtocol,
        runningIn queue: DispatchQueue,
        numberOfExtrinsics: Int,
        completion completionClosure: @escaping ExtrinsicSubmitIndexedClosure
    ) {
        let wrapper = operationFactory.submit(closure, signer: signer, numberOfExtrinsics: numberOfExtrinsics)

        wrapper.targetOperation.completionBlock = {
            queue.async {
                do {
                    let operationResult = try wrapper.targetOperation.extractNoCancellableResultData()
                    completionClosure(operationResult)
                } catch {
                    let result = SubmitIndexedExtrinsicResult(
                        builderClosure: closure,
                        error: error,
                        indexes: Array(0 ..< numberOfExtrinsics)
                    )

                    completionClosure(result)
                }
            }
        }

        operationManager.enqueue(operations: wrapper.allOperations, in: .transient)
    }
}
