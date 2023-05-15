import Foundation
import BigInt
import RobinHood
import SwiftRLP
import SubstrateSdk

final class DAppEthereumConfirmInteractor: DAppOperationBaseInteractor {
    let request: DAppOperationRequest
    let ethereumOperationFactory: EthereumOperationFactoryProtocol
    let operationQueue: OperationQueue
    let signingWrapperFactory: SigningWrapperFactoryProtocol
    let serializationFactory: EthereumSerializationFactoryProtocol
    let shouldSendTransaction: Bool
    let chainId: String

    init(
        chainId: String,
        request: DAppOperationRequest,
        ethereumOperationFactory: EthereumOperationFactoryProtocol,
        operationQueue: OperationQueue,
        signingWrapperFactory: SigningWrapperFactoryProtocol,
        serializationFactory: EthereumSerializationFactoryProtocol,
        shouldSendTransaction: Bool
    ) {
        self.chainId = chainId
        self.request = request
        self.ethereumOperationFactory = ethereumOperationFactory
        self.operationQueue = operationQueue
        self.signingWrapperFactory = signingWrapperFactory
        self.serializationFactory = serializationFactory
        self.shouldSendTransaction = shouldSendTransaction
    }

    private func createGasLimitOperation(for transaction: EthereumTransaction) -> BaseOperation<String> {
        if let gasLimit = transaction.gas, let value = try? BigUInt(hex: gasLimit), value > 0 {
            return BaseOperation.createWithResult(gasLimit)
        } else {
            let gasTransaction = EthereumTransaction.gasEstimationTransaction(from: transaction)
            return ethereumOperationFactory.createGasLimitOperation(for: gasTransaction)
        }
    }

    private func createGasPriceOperation(for transaction: EthereumTransaction) -> BaseOperation<String> {
        if let gasPrice = transaction.gasPrice, let value = try? BigUInt(hex: gasPrice), value > 0 {
            return BaseOperation.createWithResult(gasPrice)
        } else {
            return ethereumOperationFactory.createGasPriceOperation()
        }
    }

    private func createNonceOperation(for transaction: EthereumTransaction) -> BaseOperation<String> {
        if let nonce = transaction.nonce {
            return BaseOperation.createWithResult(nonce)
        } else {
            guard let addressData = try? Data(hexString: transaction.from) else {
                let error = DAppOperationConfirmInteractorError.extrinsicBadField(name: "from")
                return BaseOperation.createWithError(error)
            }

            return ethereumOperationFactory.createTransactionsCountOperation(
                for: addressData,
                block: .pending
            )
        }
    }

    private func createSigningTransactionWrapper(
        for request: DAppOperationRequest
    ) -> CompoundOperationWrapper<EthereumTransaction> {
        guard let transaction = try? request.operationData.map(to: EthereumTransaction.self) else {
            let error = DAppOperationConfirmInteractorError.extrinsicBadField(name: "root")
            return CompoundOperationWrapper.createWithError(error)
        }

        let nonceOperation = createNonceOperation(for: transaction)
        let gasOperation = createGasLimitOperation(for: transaction)
        let gasPriceOperation = createGasPriceOperation(for: transaction)

        let mapOperation = ClosureOperation<EthereumTransaction> {
            let nonce = try nonceOperation.extractNoCancellableResultData()
            let gas = try gasOperation.extractNoCancellableResultData()
            let gasPrice = try gasPriceOperation.extractNoCancellableResultData()

            let gasTransaction = EthereumTransaction.gasEstimationTransaction(from: transaction)
            return gasTransaction
                .replacing(gas: gas)
                .replacing(gasPrice: gasPrice)
                .replacing(nonce: nonce)
        }

        let dependencies = [gasOperation, gasPriceOperation, nonceOperation]
        dependencies.forEach { mapOperation.addDependency($0) }

        return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: dependencies)
    }

    private func createSerializationOperation(
        chainId: String,
        dependingOn transactionOperation: BaseOperation<EthereumTransaction>,
        signatureOperation: BaseOperation<Data>?,
        serializationFactory: EthereumSerializationFactoryProtocol
    ) -> BaseOperation<Data> {
        ClosureOperation {
            let transaction = try transactionOperation.extractNoCancellableResultData()
            let maybeRawSignature = try signatureOperation?.extractNoCancellableResultData()

            let maybeSignature = try maybeRawSignature.map { rawSignature in
                guard let signature = EthereumSignature(rawValue: rawSignature) else {
                    throw DAppOperationConfirmInteractorError.signingFailed
                }

                return signature
            }

            return try serializationFactory.serialize(
                transaction: transaction,
                chainId: chainId,
                signature: maybeSignature
            )
        }
    }

    private func createSigningOperation(
        using wallet: MetaAccountModel,
        dependingOn signingDataOperation: BaseOperation<Data>,
        transactionOperation: BaseOperation<EthereumTransaction>,
        signingWrapperFactory: SigningWrapperFactoryProtocol
    ) -> BaseOperation<Data> {
        ClosureOperation {
            let transaction = try transactionOperation.extractNoCancellableResultData()
            let signingData = try signingDataOperation.extractNoCancellableResultData()

            guard
                let addressData = try? Data(hexString: transaction.from),
                let accountResponse = wallet.fetchEthereum(for: addressData) else {
                throw ChainAccountFetchingError.accountNotExists
            }

            let signingWrapper = signingWrapperFactory.createSigningWrapper(for: accountResponse)

            return try signingWrapper.sign(signingData).rawData()
        }
    }

    private func provideConfirmationModel() {
        guard
            let transaction = try? request.operationData.map(to: EthereumTransaction.self),
            let chainAccountId = try? Data(hexString: transaction.from) else {
            presenter?.didReceive(feeResult: .failure(ChainAccountFetchingError.accountNotExists))
            return
        }

        let model = DAppOperationConfirmModel(
            accountName: request.wallet.name,
            walletIdenticon: request.wallet.walletIdenticonData(),
            chainAccountId: chainAccountId,
            chainAddress: transaction.from,
            dApp: request.dApp,
            dAppIcon: request.dAppIcon
        )

        presenter?.didReceive(modelResult: .success(model))
    }

    private func provideFeeViewModel() {
        guard let transaction = try? request.operationData.map(to: EthereumTransaction.self) else {
            let result: Result<RuntimeDispatchInfo, Error> = .failure(
                DAppOperationConfirmInteractorError.extrinsicBadField(name: "root")
            )
            presenter?.didReceive(feeResult: result)
            return
        }

        let gasOperation = createGasLimitOperation(for: transaction)
        let gasPriceOperation = createGasPriceOperation(for: transaction)

        let mapOperation = ClosureOperation<RuntimeDispatchInfo> {
            let gasHex = try gasOperation.extractNoCancellableResultData()
            let gasPriceHex = try gasPriceOperation.extractNoCancellableResultData()

            guard
                let gas = BigUInt.fromHexString(gasHex),
                let gasPrice = BigUInt.fromHexString(gasPriceHex) else {
                throw DAppOperationConfirmInteractorError.extrinsicBadField(name: "gas")
            }

            let fee = gas * gasPrice

            return RuntimeDispatchInfo(
                fee: String(fee),
                weight: 0
            )
        }

        mapOperation.addDependency(gasOperation)
        mapOperation.addDependency(gasPriceOperation)

        mapOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                do {
                    let dispatchInfo = try mapOperation.extractNoCancellableResultData()
                    self?.presenter?.didReceive(feeResult: .success(dispatchInfo))
                } catch {
                    self?.presenter?.didReceive(feeResult: .failure(error))
                }
            }
        }

        operationQueue.addOperations(
            [gasOperation, gasPriceOperation, mapOperation],
            waitUntilFinished: false
        )
    }

    private func confirmSend() {
        let transactionWrapper = createSigningTransactionWrapper(for: request)
        let signatureDataOperation = createSerializationOperation(
            chainId: chainId,
            dependingOn: transactionWrapper.targetOperation,
            signatureOperation: nil,
            serializationFactory: serializationFactory
        )

        signatureDataOperation.addDependency(transactionWrapper.targetOperation)

        let signingOperation = createSigningOperation(
            using: request.wallet,
            dependingOn: signatureDataOperation,
            transactionOperation: transactionWrapper.targetOperation,
            signingWrapperFactory: signingWrapperFactory
        )

        signingOperation.addDependency(signatureDataOperation)
        signingOperation.addDependency(transactionWrapper.targetOperation)

        let serializationOperation = createSerializationOperation(
            chainId: chainId,
            dependingOn: transactionWrapper.targetOperation,
            signatureOperation: signingOperation,
            serializationFactory: serializationFactory
        )

        serializationOperation.addDependency(transactionWrapper.targetOperation)
        serializationOperation.addDependency(signingOperation)

        let sendOperation = ethereumOperationFactory.createSendTransactionOperation {
            try serializationOperation.extractNoCancellableResultData()
        }

        sendOperation.addDependency(serializationOperation)

        sendOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                guard let strongSelf = self else {
                    return
                }

                do {
                    let txHash = try sendOperation.extractNoCancellableResultData()
                    let txHashData = try Data(hexString: txHash)
                    let response = DAppOperationResponse(signature: txHashData)
                    let result: Result<DAppOperationResponse, Error> = .success(response)
                    strongSelf.presenter?.didReceive(responseResult: result, for: strongSelf.request)
                } catch {
                    let result: Result<DAppOperationResponse, Error> = .failure(error)
                    strongSelf.presenter?.didReceive(responseResult: result, for: strongSelf.request)
                }
            }
        }

        let allOperations = transactionWrapper.allOperations +
            [signatureDataOperation, signingOperation, serializationOperation, sendOperation]

        operationQueue.addOperations(allOperations, waitUntilFinished: false)
    }

    private func confirmSign() {
        let transactionWrapper = createSigningTransactionWrapper(for: request)
        let signatureDataOperation = createSerializationOperation(
            chainId: chainId,
            dependingOn: transactionWrapper.targetOperation,
            signatureOperation: nil,
            serializationFactory: serializationFactory
        )

        signatureDataOperation.addDependency(transactionWrapper.targetOperation)

        let signingOperation = createSigningOperation(
            using: request.wallet,
            dependingOn: signatureDataOperation,
            transactionOperation: transactionWrapper.targetOperation,
            signingWrapperFactory: signingWrapperFactory
        )

        signingOperation.addDependency(signatureDataOperation)
        signingOperation.addDependency(transactionWrapper.targetOperation)

        let serializationOperation = createSerializationOperation(
            chainId: chainId,
            dependingOn: transactionWrapper.targetOperation,
            signatureOperation: signingOperation,
            serializationFactory: serializationFactory
        )

        serializationOperation.addDependency(transactionWrapper.targetOperation)
        serializationOperation.addDependency(signingOperation)

        serializationOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                guard let strongSelf = self else {
                    return
                }

                do {
                    let transaction = try serializationOperation.extractNoCancellableResultData()
                    let response = DAppOperationResponse(signature: transaction)
                    let result: Result<DAppOperationResponse, Error> = .success(response)
                    strongSelf.presenter?.didReceive(responseResult: result, for: strongSelf.request)
                } catch {
                    let result: Result<DAppOperationResponse, Error> = .failure(error)
                    strongSelf.presenter?.didReceive(responseResult: result, for: strongSelf.request)
                }
            }
        }

        let allOperations = transactionWrapper.allOperations +
            [signatureDataOperation, signingOperation, serializationOperation]

        operationQueue.addOperations(allOperations, waitUntilFinished: false)
    }
}

extension DAppEthereumConfirmInteractor: DAppOperationConfirmInteractorInputProtocol {
    func setup() {
        provideConfirmationModel()
        provideFeeViewModel()
    }

    func estimateFee() {
        provideFeeViewModel()
    }

    func confirm() {
        if shouldSendTransaction {
            confirmSend()
        } else {
            confirmSign()
        }
    }

    func reject() {
        let response = DAppOperationResponse(signature: nil)
        presenter?.didReceive(responseResult: .success(response), for: request)
    }

    func prepareTxDetails() {
        presenter?.didReceive(txDetailsResult: .success(request.operationData))
    }
}
