import Foundation
import BigInt
import SubstrateSdk
import Operation_iOS

typealias EvmFeeTransactionResult = Result<EvmFeeModel, Error>
typealias EvmEstimateFeeClosure = (EvmFeeTransactionResult) -> Void
typealias EvmSubmitTransactionResult = Result<String, Error>
typealias EvmSignTransactionResult = Result<Data, Error>
typealias EvmTransactionSubmitClosure = (EvmSubmitTransactionResult) -> Void
typealias EvmTransactionSignClosure = (EvmSignTransactionResult) -> Void
typealias EvmTransactionBuilderClosure = (EvmTransactionBuilderProtocol) throws -> EvmTransactionBuilderProtocol
typealias EvmSubscriptionIdClosure = (UInt16) -> Bool
typealias EvmSubscriptionStatusClosure = (Result<EthereumTransactionReceipt, Error>) -> Void

protocol EvmTransactionServiceProtocol {
    func estimateFee(
        _ closure: @escaping EvmTransactionBuilderClosure,
        runningIn queue: DispatchQueue,
        completion completionClosure: @escaping EvmEstimateFeeClosure
    )

    func submit(
        _ closure: @escaping EvmTransactionBuilderClosure,
        price: EvmTransactionPrice,
        signer: SigningWrapperProtocol,
        runningIn queue: DispatchQueue,
        completion completionClosure: @escaping EvmTransactionSubmitClosure
    )
    
    func submitAndWatch(
        _ closure: @escaping EvmTransactionBuilderClosure,
        price: EvmTransactionPrice,
        signer: SigningWrapperProtocol,
        runningIn queue: DispatchQueue,
        subscriptionIdClosure: @escaping EvmSubscriptionIdClosure,
        notificationClosure: @escaping EvmSubscriptionStatusClosure
    )

    func sign(
        _ closure: @escaping EvmTransactionBuilderClosure,
        price: EvmTransactionPrice,
        signer: SigningWrapperProtocol,
        runningIn queue: DispatchQueue,
        completion completionClosure: @escaping EvmTransactionSignClosure
    )
}

final class EvmTransactionService {
    let accountId: AccountId
    let operationFactory: EthereumOperationFactoryProtocol
    let maxPriorityGasPriceProvider: EvmGasPriceProviderProtocol
    let defaultGasPriceProvider: EvmGasPriceProviderProtocol
    let gasLimitProvider: EvmGasLimitProviderProtocol
    let nonceProvider: EvmNonceProviderProtocol
    let chainFormat: ChainFormat
    let evmChainId: String
    let operationQueue: OperationQueue
    let logger: LoggerProtocol

    init(
        accountId: AccountId,
        operationFactory: EthereumOperationFactoryProtocol,
        maxPriorityGasPriceProvider: EvmGasPriceProviderProtocol,
        defaultGasPriceProvider: EvmGasPriceProviderProtocol,
        gasLimitProvider: EvmGasLimitProviderProtocol,
        nonceProvider: EvmNonceProviderProtocol,
        chain: ChainModel,
        operationQueue: OperationQueue,
        logger: LoggerProtocol = Logger.shared
    ) {
        self.accountId = accountId
        self.operationFactory = operationFactory
        self.maxPriorityGasPriceProvider = maxPriorityGasPriceProvider
        self.defaultGasPriceProvider = defaultGasPriceProvider
        self.gasLimitProvider = gasLimitProvider
        self.nonceProvider = nonceProvider
        chainFormat = chain.chainFormat
        evmChainId = chain.evmChainId
        self.operationQueue = operationQueue
        self.logger = logger
    }

    init(
        accountId: AccountId,
        operationFactory: EthereumOperationFactoryProtocol,
        maxPriorityGasPriceProvider: EvmGasPriceProviderProtocol,
        defaultGasPriceProvider: EvmGasPriceProviderProtocol,
        gasLimitProvider: EvmGasLimitProviderProtocol,
        nonceProvider: EvmNonceProviderProtocol,
        chainFormat: ChainFormat,
        evmChainId: String,
        operationQueue: OperationQueue,
        logger: LoggerProtocol = Logger.shared
    ) {
        self.accountId = accountId
        self.operationFactory = operationFactory
        self.maxPriorityGasPriceProvider = maxPriorityGasPriceProvider
        self.defaultGasPriceProvider = defaultGasPriceProvider
        self.gasLimitProvider = gasLimitProvider
        self.nonceProvider = nonceProvider
        self.chainFormat = chainFormat
        self.evmChainId = evmChainId
        self.operationQueue = operationQueue
        self.logger = logger
    }
}

// MARK: - Private

private extension EvmTransactionService {
    func createSubmitAndSubscribeWrapper(
        _ closure: @escaping EvmTransactionBuilderClosure,
        price: EvmTransactionPrice,
        signer: SigningWrapperProtocol,
        subscriptionQueue: DispatchQueue,
        subscriptionIdClosure: @escaping EvmSubscriptionIdClosure,
        notificationClosure: @escaping EvmSubscriptionStatusClosure
    ) -> CompoundOperationWrapper<String> {
        do {
            let transactionWrapper = try createSignedTransactionWrapper(
                closure,
                price: price,
                signer: signer
            )
            
            let subscriptionOperation = createSubscriptionOperation(
                rawTransaction: { try transactionWrapper.targetOperation.extractNoCancellableResultData() },
                runningIn: subscriptionQueue,
                subscriptionIdClosure: subscriptionIdClosure,
                notificationClosure: notificationClosure
            )

            let sendOperation = operationFactory.createSendTransactionOperation {
                try transactionWrapper.targetOperation.extractNoCancellableResultData()
            }

            subscriptionOperation.addDependency(transactionWrapper.targetOperation)
            sendOperation.addDependency(subscriptionOperation)
            
            let wrapper = CompoundOperationWrapper(
                targetOperation: sendOperation,
                dependencies: transactionWrapper.allOperations + [subscriptionOperation]
            )
            
            return wrapper
        } catch {
            return .createWithError(error)
        }
    }
    
    func createSubscriptionOperation(
        rawTransaction: @escaping () throws -> Data,
        runningIn queue: DispatchQueue,
        subscriptionIdClosure: @escaping EvmSubscriptionIdClosure,
        notificationClosure: @escaping EvmSubscriptionStatusClosure
    ) -> BaseOperation<Void> {
        ClosureOperation { [weak self] in
            guard let self else { return }
            
            let txHash = try rawTransaction().keccak256().toHex()
            
            let updateClosure: (JSONRPCSubscriptionUpdate<EvmSubscriptionMessage.NewHeadsUpdate>) -> Void
            updateClosure = { [weak self, txHash] update in
                guard
                    let chainId = self?.evmChainId,
                    let receiptOperation = self?.operationFactory.createTransactionReceiptOperation(for: txHash),
                    let operationQueue = self?.operationQueue
                else { return }
                
                let blockNumber = update.params.result.blockNumber

                self?.logger.debug("Did receive new evm block: \(blockNumber) \(chainId)")
                
                execute(
                    operation: receiptOperation,
                    inOperationQueue: operationQueue,
                    runningCallbackIn: queue
                ) { result in
                    switch result {
                    case let .success(receipt):
                        guard let receipt else { return }
                        notificationClosure(.success(receipt))
                    case let .failure(error):
                        notificationClosure(.failure(error))
                    }
                }
            }

            let failureClosure: (Error, Bool) -> Void = { [weak self] error, unsubscribed in
                queue.async { notificationClosure(.failure(error)) }
                self?.logger.error("Did receive subscription error: \(error) \(unsubscribed)")
            }

            let subscriptionId = try operationFactory.connection.subscribe(
                EvmSubscriptionMessage.subscribeMethod,
                params: EvmSubscriptionMessage.NewHeadsParams(),
                unsubscribeMethod: EvmSubscriptionMessage.unsubscribeMethod,
                updateClosure: updateClosure,
                failureClosure: failureClosure
            )

            guard subscriptionIdClosure(subscriptionId) else {
                operationFactory.connection.cancelForIdentifier(subscriptionId)
                return
            }
            
            logger.debug("Did create evm native balance subscription: \(evmChainId)")
        }
    }
    
    func createSignedTransactionWrapper(
        _ closure: @escaping EvmTransactionBuilderClosure,
        price: EvmTransactionPrice,
        signer: SigningWrapperProtocol
    ) throws -> CompoundOperationWrapper<Data> {
        let address = try accountId.toAddress(using: chainFormat)
        let initBuilder = EvmTransactionBuilder(address: address, chainId: evmChainId)
        let builder = try closure(initBuilder)

        let nonceWrapper = nonceProvider.getNonceWrapper(for: accountId, block: .pending)

        let buildOperation = ClosureOperation<Data> {
            let nonce = try nonceWrapper.targetOperation.extractNoCancellableResultData()

            return try builder
                .usingGasLimit(price.gasLimit)
                .usingGasPrice(price.gasPrice)
                .usingNonce(nonce)
                .signing(using: { data in
                    try signer.sign(data, context: .evmTransaction).rawData()
                })
                .build()
        }

        buildOperation.addDependency(nonceWrapper.targetOperation)

        let dependencies = nonceWrapper.allOperations

        return CompoundOperationWrapper(targetOperation: buildOperation, dependencies: dependencies)
    }
}

// MARK: - EvmTransactionServiceProtocol

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
            let defaultGasPriceWrapper = defaultGasPriceProvider.getGasPriceWrapper()
            let maxPriorityPriceWrapper = maxPriorityGasPriceProvider.getGasPriceWrapper()

            let mapOperation = ClosureOperation<EvmFeeModel> {
                let gasLimit = try gasEstimationWrapper.targetOperation.extractNoCancellableResultData()
                let defaultGasPrice = try defaultGasPriceWrapper.targetOperation.extractNoCancellableResultData()
                let maxPriorityGasPrice = try? maxPriorityPriceWrapper.targetOperation.extractNoCancellableResultData()

                return EvmFeeModel(
                    gasLimit: gasLimit,
                    defaultGasPrice: defaultGasPrice,
                    maxPriorityGasPrice: maxPriorityGasPrice
                )
            }

            mapOperation.addDependency(gasEstimationWrapper.targetOperation)
            mapOperation.addDependency(defaultGasPriceWrapper.targetOperation)
            mapOperation.addDependency(maxPriorityPriceWrapper.targetOperation)

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

            let operations = gasEstimationWrapper.allOperations + defaultGasPriceWrapper.allOperations +
                maxPriorityPriceWrapper.allOperations + [mapOperation]

            operationQueue.addOperations(operations, waitUntilFinished: false)
        } catch {
            dispatchInQueueWhenPossible(queue) {
                completionClosure(.failure(error))
            }
        }
    }

    func submit(
        _ closure: @escaping EvmTransactionBuilderClosure,
        price: EvmTransactionPrice,
        signer: SigningWrapperProtocol,
        runningIn queue: DispatchQueue,
        completion completionClosure: @escaping EvmTransactionSubmitClosure
    ) {
        do {
            let transactionWrapper = try createSignedTransactionWrapper(
                closure,
                price: price,
                signer: signer
            )

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
    
    func submitAndWatch(
        _ closure: @escaping EvmTransactionBuilderClosure,
        price: EvmTransactionPrice,
        signer: SigningWrapperProtocol,
        runningIn queue: DispatchQueue,
        subscriptionIdClosure: @escaping EvmSubscriptionIdClosure,
        notificationClosure: @escaping EvmSubscriptionStatusClosure
    ) {
        let wrapper = createSubmitAndSubscribeWrapper(
            closure,
            price: price,
            signer: signer,
            subscriptionQueue: queue,
            subscriptionIdClosure: subscriptionIdClosure,
            notificationClosure: notificationClosure
        )
        
        operationQueue.addOperations(wrapper.allOperations, waitUntilFinished: false)
    }

    func sign(
        _ closure: @escaping EvmTransactionBuilderClosure,
        price: EvmTransactionPrice,
        signer: SigningWrapperProtocol,
        runningIn queue: DispatchQueue,
        completion completionClosure: @escaping EvmTransactionSignClosure
    ) {
        do {
            let transactionWrapper = try createSignedTransactionWrapper(
                closure,
                price: price,
                signer: signer
            )

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
