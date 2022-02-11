import Foundation
import BigInt
import RobinHood
import SwiftRLP
import SubstrateSdk

final class DAppEthereumConfirmInteractor: DAppOperationBaseInteractor {
    let request: DAppOperationRequest
    let chain: MetamaskChain
    let ethereumOperationFactory: EthereumOperationFactoryProtocol
    let operationQueue: OperationQueue
    let signingWrapperFactory: SigningWrapperFactoryProtocol

    init(
        request: DAppOperationRequest,
        chain: MetamaskChain,
        ethereumOperationFactory: EthereumOperationFactoryProtocol,
        operationQueue: OperationQueue,
        signingWrapperFactory: SigningWrapperFactoryProtocol
    ) {
        self.request = request
        self.chain = chain
        self.ethereumOperationFactory = ethereumOperationFactory
        self.operationQueue = operationQueue
        self.signingWrapperFactory = signingWrapperFactory
    }

    private func createSigningTransactionWrapper(
        for request: DAppOperationRequest
    ) -> CompoundOperationWrapper<EthereumTransaction> {
        guard let transaction = try? request.operationData.map(to: MetamaskTransaction.self) else {
            let error = DAppOperationConfirmInteractorError.extrinsicBadField(name: "root")
            return CompoundOperationWrapper.createWithError(error)
        }

        guard let addressData = try? Data(hexString: transaction.from) else {
            let error = DAppOperationConfirmInteractorError.extrinsicBadField(name: "from")
            return CompoundOperationWrapper.createWithError(error)
        }

        let nonceOperation = ethereumOperationFactory.createTransactionsCountOperation(
            for: addressData,
            block: .pending
        )

        let gasTransaction = EthereumTransaction.gasEstimationTransaction(from: transaction)

        let gasOperation = ethereumOperationFactory.createGasLimitOperation(for: gasTransaction)
        let gasPriceOperation = ethereumOperationFactory.createGasPriceOperation()

        let mapOperation = ClosureOperation<EthereumTransaction> {
            let nonce = try nonceOperation.extractNoCancellableResultData()
            let gas = try gasOperation.extractNoCancellableResultData()
            let gasPrice = try gasPriceOperation.extractNoCancellableResultData()

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
        chain: MetamaskChain,
        dependingOn transactionOperation: BaseOperation<EthereumTransaction>,
        signatureOperation: BaseOperation<EthereumSignature>?
    ) -> BaseOperation<Data> {
        ClosureOperation {
            let transaction = try transactionOperation.extractNoCancellableResultData()
            let maybeSignature = try signatureOperation?.extractNoCancellableResultData()

            guard let nonceHex = transaction.nonce, let nonce = BigUInt.fromHexString(nonceHex) else {
                throw DAppOperationConfirmInteractorError.extrinsicBadField(name: "nonce")
            }

            guard let gasHex = transaction.gas, let gas = BigUInt.fromHexString(gasHex) else {
                throw DAppOperationConfirmInteractorError.extrinsicBadField(name: "gas")
            }

            guard
                let gasPriceHex = transaction.gasPrice,
                let gasPrice = BigUInt.fromHexString(gasPriceHex) else {
                throw DAppOperationConfirmInteractorError.extrinsicBadField(name: "gasPrice")
            }

            guard let to = transaction.to, let toAddress = try? Data(hexString: to) else {
                throw DAppOperationConfirmInteractorError.extrinsicBadField(name: "gasPrice")
            }

            guard let valueHex = transaction.value, let value = BigUInt.fromHexString(valueHex) else {
                throw DAppOperationConfirmInteractorError.extrinsicBadField(name: "value")
            }

            guard let data = try? Data(hexString: transaction.data) else {
                throw DAppOperationConfirmInteractorError.extrinsicBadField(name: "data")
            }

            var fields = [
                nonce,
                gasPrice,
                gas,
                toAddress,
                value,
                data
            ] as [AnyObject]

            guard let chainId = BigUInt.fromHexString(chain.chainId) else {
                throw DAppOperationConfirmInteractorError.extrinsicBadField(name: "chainId")
            }

            if let signature = maybeSignature {
                let dPart: BigUInt

                if signature.vPart >= 0, signature.vPart <= 3 {
                    dPart = BigUInt(35)
                } else if signature.vPart >= 27, signature.vPart <= 30 {
                    dPart = BigUInt(8)
                } else if signature.vPart >= 31, signature.vPart <= 34 {
                    dPart = BigUInt(4)
                } else {
                    dPart = BigUInt(0)
                }

                let vPart = BigUInt(signature.vPart) + dPart + chainId + chainId
                let rPart = BigUInt(signature.rPart.value)
                let sPart = BigUInt(signature.sPart.value)

                let signatureList = [vPart, rPart, sPart] as [AnyObject]

                fields.append(contentsOf: signatureList)
            } else {
                let chainList = [
                    chainId,
                    BigUInt(0),
                    BigUInt(0)
                ] as [AnyObject]

                fields.append(contentsOf: chainList)
            }

            guard let serializedData = RLP.encode(fields) else {
                throw DAppOperationConfirmInteractorError.extrinsicBadField(name: "signing data")
            }

            return serializedData
        }
    }

    private func createSigningOperation(
        using wallet: MetaAccountModel,
        dependingOn signingDataOperation: BaseOperation<Data>,
        transactionOperation: BaseOperation<EthereumTransaction>,
        signingWrapperFactory: SigningWrapperFactoryProtocol
    ) -> BaseOperation<EthereumSignature> {
        ClosureOperation {
            let transaction = try transactionOperation.extractNoCancellableResultData()
            let signingData = try signingDataOperation.extractNoCancellableResultData()

            guard
                let addressData = try? Data(hexString: transaction.from),
                let accountResponse = wallet.fetchEthereum(for: addressData) else {
                throw ChainAccountFetchingError.accountNotExists
            }

            let signingWrapper = signingWrapperFactory.createSigningWrapper(for: accountResponse)

            let rawSignature = try signingWrapper.sign(signingData).rawData()

            guard let signature = EthereumSignature(rawValue: rawSignature) else {
                throw DAppOperationConfirmInteractorError.signingFailed
            }

            return signature
        }
    }

    private func provideConfirmationModel() {
        guard
            let transaction = try? request.operationData.map(to: MetamaskTransaction.self),
            let chainAccountId = try? Data(hexString: transaction.from) else {
            presenter?.didReceive(feeResult: .failure(ChainAccountFetchingError.accountNotExists))
            return
        }

        let model = DAppOperationConfirmModel(
            accountName: request.wallet.name,
            walletAccountId: request.wallet.substrateAccountId,
            chainAccountId: chainAccountId,
            chainAddress: transaction.from,
            networkName: chain.chainName,
            utilityAssetPrecision: chain.nativeCurrency.decimals,
            dApp: request.dApp,
            dAppIcon: request.dAppIcon,
            networkIcon: request.dAppIcon
        )

        presenter?.didReceive(modelResult: .success(model))
    }

    private func provideFeeViewModel() {
        guard let transaction = try? request.operationData.map(to: MetamaskTransaction.self) else {
            let result: Result<RuntimeDispatchInfo, Error> = .failure(
                DAppOperationConfirmInteractorError.extrinsicBadField(name: "root")
            )
            presenter?.didReceive(feeResult: result)
            return
        }

        let gasTransaction = EthereumTransaction.gasEstimationTransaction(from: transaction)

        let gasOperation = ethereumOperationFactory.createGasLimitOperation(for: gasTransaction)
        let gasPriceOperation = ethereumOperationFactory.createGasPriceOperation()

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
                dispatchClass: "ethereum",
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
        let transactionWrapper = createSigningTransactionWrapper(for: request)
        let signatureDataOperation = createSerializationOperation(
            chain: chain,
            dependingOn: transactionWrapper.targetOperation,
            signatureOperation: nil
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
            chain: chain,
            dependingOn: transactionWrapper.targetOperation,
            signatureOperation: signingOperation
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
                    strongSelf.presenter?.didReceive(
                        responseResult: .success(response),
                        for: strongSelf.request
                    )
                } catch {
                    strongSelf.presenter?.didReceive(
                        responseResult: .failure(error),
                        for: strongSelf.request
                    )
                }
            }
        }

        let allOperations = transactionWrapper.allOperations +
            [signatureDataOperation, signingOperation, serializationOperation, sendOperation]

        operationQueue.addOperations(allOperations, waitUntilFinished: false)
    }

    func reject() {
        let response = DAppOperationResponse(signature: nil)
        presenter?.didReceive(responseResult: .success(response), for: request)
    }

    func prepareTxDetails() {
        presenter?.didReceive(txDetailsResult: .success(request.operationData))
    }
}
