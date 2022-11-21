import Foundation
import BigInt
import SubstrateSdk
import RobinHood

typealias EvmFeeTransactionResult = Result<BigUInt, Error>
typealias EvmEstimateFeeClosure = (EvmFeeTransactionResult) -> Void
typealias EvmSubmitTransactionResult = Result<String, Error>
typealias EvmTransactionSubmitClosure = (EvmSubmitTransactionResult) -> Void
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
}

enum EvmTransactionServiceError: Error {
    case invalidGasLimit(String)
    case invalidGasPrice(String)
    case invalidNonce(String)
}

final class EvmTransactionService {
    let accountId: AccountId
    let operationFactory: EthereumOperationFactoryProtocol
    let chain: ChainModel
    let connection: JSONRPCEngine
    let operationQueue: OperationQueue

    init(
        accountId: AccountId,
        operationFactory: EthereumOperationFactoryProtocol,
        chain: ChainModel,
        connection: JSONRPCEngine,
        operationQueue: OperationQueue
    ) {
        self.accountId = accountId
        self.operationFactory = operationFactory
        self.chain = chain
        self.connection = connection
        self.operationQueue = operationQueue
    }
}

extension EvmTransactionService: EvmTransactionServiceProtocol {
    func estimateFee(
        _ closure: @escaping EvmTransactionBuilderClosure,
        runningIn queue: DispatchQueue,
        completion completionClosure: @escaping EvmEstimateFeeClosure
    ) {
        do {
            let address = try accountId.toAddress(using: chain.chainFormat)
            let builder = EvmTransactionBuilder(address: address, chainId: chain.evmChainId)
            let transaction = (try closure(builder)).buildTransaction()

            let gasEstimationOperation = operationFactory.createGasLimitOperation(for: transaction)
            let gasPriceOperation = operationFactory.createGasPriceOperation()

            let mapOperation = ClosureOperation<BigUInt> {
                let gasLimitString = try gasEstimationOperation.extractNoCancellableResultData()
                let gasPriceString = try gasPriceOperation.extractNoCancellableResultData()

                guard let gasLimit = BigUInt(gasLimitString) else {
                    throw EvmTransactionServiceError.invalidGasLimit(gasLimitString)
                }

                guard let gasPrice = BigUInt(gasPriceString) else {
                    throw EvmTransactionServiceError.invalidGasPrice(gasPriceString)
                }

                return gasLimit * gasPrice
            }

            mapOperation.addDependency(gasEstimationOperation)
            mapOperation.addDependency(gasPriceOperation)

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

            let operations = [gasEstimationOperation, gasPriceOperation, mapOperation]

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
            let address = try accountId.toAddress(using: chain.chainFormat)
            let initBuilder = EvmTransactionBuilder(address: address, chainId: chain.evmChainId)
            let builder = try closure(initBuilder)

            let gasEstimationOperation = operationFactory.createGasLimitOperation(for: builder.buildTransaction())
            let gasPriceOperation = operationFactory.createGasPriceOperation()
            let nonceOperation = operationFactory.createTransactionsCountOperation(for: accountId, block: .pending)

            let sendOperation = operationFactory.createSendTransactionOperation {
                let gasLimitString = try gasEstimationOperation.extractNoCancellableResultData()
                let gasPriceString = try gasPriceOperation.extractNoCancellableResultData()
                let nonceString = try nonceOperation.extractNoCancellableResultData()

                guard let gasLimit = BigUInt(gasLimitString) else {
                    throw EvmTransactionServiceError.invalidGasLimit(gasLimitString)
                }

                guard let gasPrice = BigUInt(gasPriceString) else {
                    throw EvmTransactionServiceError.invalidGasPrice(gasLimitString)
                }

                guard let nonce = UInt(nonceString) else {
                    throw EvmTransactionServiceError.invalidNonce(nonceString)
                }

                return try builder
                    .usingGasLimit(gasLimit)
                    .usingGasPrice(gasPrice)
                    .usingNonce(nonce)
                    .signing(using: { data in
                        try signer.sign(data).rawData()
                    })
                    .build()
            }

            sendOperation.addDependency(gasEstimationOperation)
            sendOperation.addDependency(gasPriceOperation)
            sendOperation.addDependency(nonceOperation)

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

            let operations = [gasEstimationOperation, gasPriceOperation, nonceOperation, sendOperation]

            operationQueue.addOperations(operations, waitUntilFinished: false)
        } catch {
            dispatchInQueueWhenPossible(queue) {
                completionClosure(.failure(error))
            }
        }
    }
}
