import Foundation
import BigInt
import SubstrateSdk
import Operation_iOS

struct EvmSubscriptionStatus {
    let lastBlockNumber: BigUInt
    let transactionHash: String
}

struct EvmSubmittedTransaction {
    let transactionHash: String
    let sender: AccountId
    let nonce: BigUInt
}

private struct EvmSignedTransaction {
    let rawData: Data
    let nonce: BigUInt

    func resolveHash(from sendResult: Result<String, Error>?, logger: LoggerProtocol) throws -> String {
        switch sendResult {
        case let .success(transactionHash):
            return transactionHash
        case let .failure(error as JSONRPCError) where error.isDefinitiveEvmSendRejection:
            throw error
        case let .failure(error):
            logger.warning("Evm send outcome is uncertain, watching local hash: \(error)")
        case .none:
            logger.warning("Evm send has no result, watching local hash")
        }

        return try rawData.keccak256().toHex(includePrefix: true)
    }
}

typealias EvmFeeTransactionResult = Result<EvmFeeModel, Error>
typealias EvmEstimateFeeClosure = (EvmFeeTransactionResult) -> Void
typealias EvmSubmitTransactionResult = Result<String, Error>
typealias EvmSignTransactionResult = Result<Data, Error>
typealias EvmTransactionSubmitClosure = (EvmSubmitTransactionResult) -> Void
typealias EvmTransactionSignClosure = (EvmSignTransactionResult) -> Void
typealias EvmTransactionBuilderClosure = (EvmTransactionBuilderProtocol) throws -> EvmTransactionBuilderProtocol
typealias EvmSubscriptionIdClosure = (UInt16) -> Bool
typealias EvmSubscriptionStatusClosure = (Result<EvmSubscriptionStatus, Error>) -> Void

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

    func cancelTransactionWatch(for subscriptionId: UInt16)

    func createSubmissionWrapper(
        _ closure: @escaping EvmTransactionBuilderClosure,
        price: EvmTransactionPrice,
        signer: SigningWrapperProtocol
    ) -> CompoundOperationWrapper<EvmSubmittedTransaction>

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
    let maxPriorityGasPriceProvider: EvmEip1559PriceProviderProtocol?
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
        maxPriorityGasPriceProvider: EvmEip1559PriceProviderProtocol?,
        defaultGasPriceProvider: EvmGasPriceProviderProtocol,
        gasLimitProvider: EvmGasLimitProviderProtocol,
        nonceProvider: EvmNonceProviderProtocol,
        chain: ChainModel,
        operationQueue: OperationQueue,
        logger: LoggerProtocol = Logger.shared
    ) {
        self.accountId = accountId
        self.operationFactory = operationFactory
        self.maxPriorityGasPriceProvider = chain.forcesLegacyEvmTransactions ? nil : maxPriorityGasPriceProvider
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
        maxPriorityGasPriceProvider: EvmEip1559PriceProviderProtocol?,
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
    ) -> CompoundOperationWrapper<Void> {
        do {
            let transactionWrapper = try createSignedTransactionWrapper(
                closure,
                price: price,
                signer: signer
            )

            let sendOperation = operationFactory.createSendTransactionOperation {
                try transactionWrapper.targetOperation.extractNoCancellableResultData().rawData
            }

            let subscriptionOperation = createSubscriptionOperation(
                transactionHash: { try sendOperation.extractNoCancellableResultData() },
                runningIn: subscriptionQueue,
                subscriptionIdClosure: subscriptionIdClosure,
                notificationClosure: notificationClosure
            )

            sendOperation.addDependency(transactionWrapper.targetOperation)
            subscriptionOperation.addDependency(sendOperation)

            let wrapper = CompoundOperationWrapper(
                targetOperation: subscriptionOperation,
                dependencies: transactionWrapper.allOperations + [sendOperation]
            )

            return wrapper
        } catch {
            return .createWithError(error)
        }
    }

    func createSubscriptionOperation(
        transactionHash: @escaping () throws -> (String),
        runningIn queue: DispatchQueue,
        subscriptionIdClosure: @escaping EvmSubscriptionIdClosure,
        notificationClosure: @escaping EvmSubscriptionStatusClosure
    ) -> BaseOperation<Void> {
        ClosureOperation {
            let transactionHash = try transactionHash()

            let updateClosure: (JSONRPCSubscriptionUpdate<EvmSubscriptionMessage.NewHeadsUpdate>) -> Void
            updateClosure = { [weak self, transactionHash] update in
                guard let chainId = self?.evmChainId else { return }

                let blockNumber = update.params.result.blockNumber

                self?.logger.debug("Did receive new evm block: \(blockNumber) \(chainId)")

                let status = EvmSubscriptionStatus(
                    lastBlockNumber: blockNumber,
                    transactionHash: transactionHash
                )

                notificationClosure(.success(status))
            }

            let failureClosure: (Error, Bool) -> Void = { [weak self] error, unsubscribed in
                queue.async { notificationClosure(.failure(error)) }
                self?.logger.error("Did receive subscription error: \(error) \(unsubscribed)")
            }

            let subscriptionId = try self.operationFactory.connection.subscribe(
                EvmSubscriptionMessage.subscribeMethod,
                params: EvmSubscriptionMessage.NewHeadsParams(),
                unsubscribeMethod: EvmSubscriptionMessage.unsubscribeMethod,
                updateClosure: updateClosure,
                failureClosure: failureClosure
            )

            guard subscriptionIdClosure(subscriptionId) else {
                self.operationFactory.connection.cancelForIdentifier(subscriptionId)
                return
            }

            self.logger.debug("Did create evm native balance subscription: \(self.evmChainId)")
        }
    }

    func createSignedTransactionWrapper(
        _ closure: @escaping EvmTransactionBuilderClosure,
        price: EvmTransactionPrice,
        signer: SigningWrapperProtocol
    ) throws -> CompoundOperationWrapper<EvmSignedTransaction> {
        let address = try accountId.toAddress(using: chainFormat)
        let initBuilder = EvmTransactionBuilder(address: address, chainId: evmChainId)
        let builder = try closure(initBuilder)

        let nonceWrapper = nonceProvider.getNonceWrapper(for: accountId, block: .pending)

        let buildOperation = ClosureOperation<EvmSignedTransaction> {
            let nonce = try nonceWrapper.targetOperation.extractNoCancellableResultData()

            let rawData = try builder
                .usingPrice(price)
                .usingNonce(nonce)
                .signing(using: { data in
                    try signer.sign(data, context: .evmTransaction).rawData()
                })
                .build()

            return EvmSignedTransaction(rawData: rawData, nonce: nonce)
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
            let eip1559PriceWrapper = maxPriorityGasPriceProvider?.getEip1559PriceWrapper()

            let mapOperation = ClosureOperation<EvmFeeModel> {
                let gasLimit = try gasEstimationWrapper.targetOperation.extractNoCancellableResultData()
                let defaultGasPrice = try defaultGasPriceWrapper.targetOperation.extractNoCancellableResultData()
                let eip1559 = try? eip1559PriceWrapper?.targetOperation.extractNoCancellableResultData()

                return EvmFeeModel(
                    gasLimit: gasLimit,
                    defaultGasPrice: defaultGasPrice,
                    eip1559: eip1559
                )
            }

            mapOperation.addDependency(gasEstimationWrapper.targetOperation)
            mapOperation.addDependency(defaultGasPriceWrapper.targetOperation)

            if let eip1559PriceWrapper {
                mapOperation.addDependency(eip1559PriceWrapper.targetOperation)
            }

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
                (eip1559PriceWrapper?.allOperations ?? []) + [mapOperation]

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
                try transactionWrapper.targetOperation.extractNoCancellableResultData().rawData
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

    func cancelTransactionWatch(for subscriptionId: UInt16) {
        operationFactory.connection.cancelForIdentifier(subscriptionId)
    }

    func createSubmissionWrapper(
        _ closure: @escaping EvmTransactionBuilderClosure,
        price: EvmTransactionPrice,
        signer: SigningWrapperProtocol
    ) -> CompoundOperationWrapper<EvmSubmittedTransaction> {
        do {
            let transactionWrapper = try createSignedTransactionWrapper(
                closure,
                price: price,
                signer: signer
            )

            let sendOperation = operationFactory.createSendTransactionOperation {
                try transactionWrapper.targetOperation.extractNoCancellableResultData().rawData
            }

            sendOperation.addDependency(transactionWrapper.targetOperation)

            let mapOperation = ClosureOperation<EvmSubmittedTransaction> { [accountId, logger] in
                let signedTransaction = try transactionWrapper.targetOperation.extractNoCancellableResultData()

                let transactionHash = try signedTransaction.resolveHash(
                    from: sendOperation.result,
                    logger: logger
                )

                return EvmSubmittedTransaction(
                    transactionHash: transactionHash,
                    sender: accountId,
                    nonce: signedTransaction.nonce
                )
            }

            mapOperation.addDependency(sendOperation)

            return CompoundOperationWrapper(
                targetOperation: mapOperation,
                dependencies: transactionWrapper.allOperations + [sendOperation]
            )
        } catch {
            return .createWithError(error)
        }
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
                        let txData = try transactionWrapper.targetOperation.extractNoCancellableResultData().rawData
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
