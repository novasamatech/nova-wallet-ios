import Foundation
import SubstrateSdk
import RobinHood
import IrohaCrypto

typealias FeeExtrinsicResult = Result<RuntimeDispatchInfo, Error>
typealias EstimateFeeClosure = (FeeExtrinsicResult) -> Void
typealias EstimateFeeIndexedClosure = ([FeeExtrinsicResult]) -> Void

typealias SubmitExtrinsicResult = Result<String, Error>
typealias ExtrinsicSubmitClosure = (SubmitExtrinsicResult) -> Void

typealias ExtrinsicSubmitIndexedClosure = ([SubmitExtrinsicResult]) -> Void

typealias ExtrinsicSubscriptionIdClosure = (UInt16) -> Bool
typealias ExtrinsicSubscriptionStatusClosure = (Result<ExtrinsicStatus, Error>) -> Void

protocol ExtrinsicServiceProtocol {
    func estimateFee(
        _ closure: @escaping ExtrinsicBuilderClosure,
        runningIn queue: DispatchQueue,
        completion completionClosure: @escaping EstimateFeeClosure
    )

    func estimateFee(
        _ closure: @escaping ExtrinsicBuilderIndexedClosure,
        runningIn queue: DispatchQueue,
        numberOfExtrinsics: Int,
        completion completionClosure: @escaping EstimateFeeIndexedClosure
    )

    func submit(
        _ closure: @escaping ExtrinsicBuilderClosure,
        signer: SigningWrapperProtocol,
        runningIn queue: DispatchQueue,
        completion completionClosure: @escaping ExtrinsicSubmitClosure
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

    func submit(
        _ closure: @escaping ExtrinsicBuilderIndexedClosure,
        signer: SigningWrapperProtocol,
        runningIn queue: DispatchQueue,
        numberOfExtrinsics: Int,
        completion completionClosure: @escaping ExtrinsicSubmitIndexedClosure
    )
}

final class ExtrinsicService {
    let operationFactory: ExtrinsicOperationFactoryProtocol
    let operationManager: OperationManagerProtocol

    init(
        accountId: AccountId,
        chain: ChainModel,
        cryptoType: MultiassetCryptoType,
        runtimeRegistry: RuntimeCodingServiceProtocol,
        engine: JSONRPCEngine,
        operationManager: OperationManagerProtocol
    ) {
        operationFactory = ExtrinsicOperationFactory(
            accountId: accountId,
            chain: chain,
            cryptoType: cryptoType,
            runtimeRegistry: runtimeRegistry,
            customExtensions: DefaultExtrinsicExtension.extensions,
            engine: engine
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
        numberOfExtrinsics: Int,
        completion completionClosure: @escaping EstimateFeeIndexedClosure
    ) {
        let wrapper = operationFactory.estimateFeeOperation(
            closure,
            numberOfExtrinsics: numberOfExtrinsics
        )

        wrapper.targetOperation.completionBlock = {
            queue.async {
                do {
                    let result = try wrapper.targetOperation.extractNoCancellableResultData()
                    completionClosure(result)
                } catch {
                    let result: [FeeExtrinsicResult] = Array(
                        repeating: .failure(error),
                        count: numberOfExtrinsics
                    )
                    completionClosure(result)
                }
            }
        }

        operationManager.enqueue(operations: wrapper.allOperations, in: .transient)
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
                    let results: [SubmitExtrinsicResult] = Array(
                        repeating: .failure(error),
                        count: numberOfExtrinsics
                    )
                    completionClosure(results)
                }
            }
        }

        operationManager.enqueue(operations: wrapper.allOperations, in: .transient)
    }
}
