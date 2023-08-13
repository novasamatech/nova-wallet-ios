import Foundation
import BigInt
import SubstrateSdk
import RobinHood

typealias EvmFeeTransactionResult = Result<BigUInt, Error>
typealias EvmEstimateFeeClosure = (EvmFeeTransactionResult) -> Void
typealias EvmSubmitTransactionResult = Result<String, Error>
typealias EvmSignTransactionResult = Result<Data, Error>
typealias EvmTransactionSubmitClosure = (EvmSubmitTransactionResult) -> Void
typealias EvmTransactionSignClosure = (EvmSignTransactionResult) -> Void
typealias EvmTransactionBuilderClosure = (EvmTransactionBuilderProtocol) throws -> EvmTransactionBuilderProtocol

protocol EvmTransactionServiceProtocol {
    func estimateFee(
        _ closure: @escaping EvmTransactionBuilderClosure,
        runningIn queue: DispatchQueue,
        completion completionClosure: @escaping EvmEstimateFeeClosure
    )

    func submit(
        _ closure: @escaping EvmTransactionBuilderClosure,
        signer: SigningWrapperProtocol,
        runningIn queue: DispatchQueue,
        completion completionClosure: @escaping EvmTransactionSubmitClosure
    )

    func sign(
        _ closure: @escaping EvmTransactionBuilderClosure,
        signer: SigningWrapperProtocol,
        runningIn queue: DispatchQueue,
        completion completionClosure: @escaping EvmTransactionSignClosure
    )
}

final class EvmTransactionService {
    let accountId: AccountId
    let operationFactory: EthereumOperationFactoryProtocol
    let gasPriceProvider: EvmGasPriceProviderProtocol
    let gasLimitProvider: EvmGasLimitProviderProtocol
    let nonceProvider: EvmNonceProviderProtocol
    let chainFormat: ChainFormat
    let evmChainId: String
    let operationQueue: OperationQueue

    init(
        accountId: AccountId,
        operationFactory: EthereumOperationFactoryProtocol,
        gasPriceProvider: EvmGasPriceProviderProtocol,
        gasLimitProvider: EvmGasLimitProviderProtocol,
        nonceProvider: EvmNonceProviderProtocol,
        chain: ChainModel,
        operationQueue: OperationQueue
    ) {
        self.accountId = accountId
        self.operationFactory = operationFactory
        self.gasPriceProvider = gasPriceProvider
        self.gasLimitProvider = gasLimitProvider
        self.nonceProvider = nonceProvider
        chainFormat = chain.chainFormat
        evmChainId = chain.evmChainId
        self.operationQueue = operationQueue
    }

    init(
        accountId: AccountId,
        operationFactory: EthereumOperationFactoryProtocol,
        gasPriceProvider: EvmGasPriceProviderProtocol,
        gasLimitProvider: EvmGasLimitProviderProtocol,
        nonceProvider: EvmNonceProviderProtocol,
        chainFormat: ChainFormat,
        evmChainId: String,
        operationQueue: OperationQueue
    ) {
        self.accountId = accountId
        self.operationFactory = operationFactory
        self.gasPriceProvider = gasPriceProvider
        self.gasLimitProvider = gasLimitProvider
        self.nonceProvider = nonceProvider
        self.chainFormat = chainFormat
        self.evmChainId = evmChainId
        self.operationQueue = operationQueue
    }

    private func createSignedTransactionWrapper(
        _ closure: @escaping EvmTransactionBuilderClosure,
        signer: SigningWrapperProtocol
    ) throws -> CompoundOperationWrapper<Data> {
        let address = try accountId.toAddress(using: chainFormat)
        let initBuilder = EvmTransactionBuilder(address: address, chainId: evmChainId)
        let builder = try closure(initBuilder)

        let gasEstimationWrapper = gasLimitProvider.getGasLimitWrapper(for: builder.buildTransaction())
        let gasPriceWrapper = gasPriceProvider.getGasPriceWrapper()
        let nonceWrapper = nonceProvider.getNonceWrapper(for: accountId, block: .pending)

        let buildOperation = ClosureOperation<Data> {
            let gasLimit = try gasEstimationWrapper.targetOperation.extractNoCancellableResultData()
            let gasPrice = try gasPriceWrapper.targetOperation.extractNoCancellableResultData()
            let nonce = try nonceWrapper.targetOperation.extractNoCancellableResultData()

            return try builder
                .usingGasLimit(gasLimit)
                .usingGasPrice(gasPrice)
                .usingNonce(nonce)
                .signing(using: { data in
                    try signer.sign(data).rawData()
                })
                .build()
        }

        buildOperation.addDependency(gasEstimationWrapper.targetOperation)
        buildOperation.addDependency(gasPriceWrapper.targetOperation)
        buildOperation.addDependency(nonceWrapper.targetOperation)

        let dependencies = gasEstimationWrapper.allOperations + gasPriceWrapper.allOperations +
            nonceWrapper.allOperations

        return CompoundOperationWrapper(targetOperation: buildOperation, dependencies: dependencies)
    }
}

extension EvmTransactionService: EvmTransactionServiceProtocol {
    func estimateFee(
        _ closure: @escaping EvmTransactionBuilderClosure,
        runningIn queue: DispatchQueue,
        completion completionClosure: @escaping EvmEstimateFeeClosure
    ) {
        do {
            let address = try accountId.toAddress(using: chainFormat)
            let builder = EvmTransactionBuilder(address: address, chainId: evmChainId)
            let transaction = (try closure(builder)).buildTransaction()

            let gasEstimationWrapper = gasLimitProvider.getGasLimitWrapper(for: transaction)
            let gasPriceWrapper = gasPriceProvider.getGasPriceWrapper()

            let mapOperation = ClosureOperation<BigUInt> {
                let gasLimit = try gasEstimationWrapper.targetOperation.extractNoCancellableResultData()
                let gasPrice = try gasPriceWrapper.targetOperation.extractNoCancellableResultData()

                return gasLimit * gasPrice
            }

            mapOperation.addDependency(gasEstimationWrapper.targetOperation)
            mapOperation.addDependency(gasPriceWrapper.targetOperation)

            mapOperation.completionBlock = {
                queue.async {
                    do {
                        let fee = try mapOperation.extractNoCancellableResultData()
                        completionClosure(.success(fee))
                    } catch {
                        completionClosure(.failure(error))
                    }
                }
            }

            let operations = gasEstimationWrapper.allOperations + gasPriceWrapper.allOperations + [mapOperation]

            operationQueue.addOperations(operations, waitUntilFinished: false)
        } catch {
            dispatchInQueueWhenPossible(queue) {
                completionClosure(.failure(error))
            }
        }
    }

    func submit(
        _ closure: @escaping EvmTransactionBuilderClosure,
        signer: SigningWrapperProtocol,
        runningIn queue: DispatchQueue,
        completion completionClosure: @escaping EvmTransactionSubmitClosure
    ) {
        do {
            let transactionWrapper = try createSignedTransactionWrapper(closure, signer: signer)

            let sendOperation = operationFactory.createSendTransactionOperation {
                try transactionWrapper.targetOperation.extractNoCancellableResultData()
            }

            sendOperation.addDependency(transactionWrapper.targetOperation)

            sendOperation.completionBlock = {
                queue.async {
                    do {
                        let hash = try sendOperation.extractNoCancellableResultData()
                        completionClosure(.success(hash))
                    } catch {
                        completionClosure(.failure(error))
                    }
                }
            }

            let operations = transactionWrapper.allOperations + [sendOperation]

            operationQueue.addOperations(operations, waitUntilFinished: false)
        } catch {
            dispatchInQueueWhenPossible(queue) {
                completionClosure(.failure(error))
            }
        }
    }

    func sign(
        _ closure: @escaping EvmTransactionBuilderClosure,
        signer: SigningWrapperProtocol,
        runningIn queue: DispatchQueue,
        completion completionClosure: @escaping EvmTransactionSignClosure
    ) {
        do {
            let transactionWrapper = try createSignedTransactionWrapper(closure, signer: signer)

            transactionWrapper.targetOperation.completionBlock = {
                queue.async {
                    do {
                        let txData = try transactionWrapper.targetOperation.extractNoCancellableResultData()
                        completionClosure(.success(txData))
                    } catch {
                        completionClosure(.failure(error))
                    }
                }
            }

            operationQueue.addOperations(transactionWrapper.allOperations, waitUntilFinished: false)
        } catch {
            dispatchInQueueWhenPossible(queue) {
                completionClosure(.failure(error))
            }
        }
    }
}
