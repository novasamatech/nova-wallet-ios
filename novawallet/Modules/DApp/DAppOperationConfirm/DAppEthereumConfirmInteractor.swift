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
    let serializationFactory: EthereumSerializationFactoryProtocol

    init(
        request: DAppOperationRequest,
        chain: MetamaskChain,
        ethereumOperationFactory: EthereumOperationFactoryProtocol,
        operationQueue: OperationQueue,
        signingWrapperFactory: SigningWrapperFactoryProtocol,
        serializationFactory: EthereumSerializationFactoryProtocol
    ) {
        self.request = request
        self.chain = chain
        self.ethereumOperationFactory = ethereumOperationFactory
        self.operationQueue = operationQueue
        self.signingWrapperFactory = signingWrapperFactory
        self.serializationFactory = serializationFactory
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
        signatureOperation: BaseOperation<EthereumSignature>?,
        serializationFactory: EthereumSerializationFactoryProtocol
    ) -> BaseOperation<Data> {
        ClosureOperation {
            let transaction = try transactionOperation.extractNoCancellableResultData()
            let maybeSignature = try signatureOperation?.extractNoCancellableResultData()

            return try serializationFactory.serialize(
                transaction: transaction,
                chainId: chain.chainId,
                signature: maybeSignature
            )
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

        let networkUrl: URL?

        if let iconUrlString = chain.iconUrls?.first, let url = URL(string: iconUrlString) {
            networkUrl = url
        } else {
            networkUrl = nil
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
            networkIcon: networkUrl
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
            chain: chain,
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

    func reject() {
        let response = DAppOperationResponse(signature: nil)
        presenter?.didReceive(responseResult: .success(response), for: request)
    }

    func prepareTxDetails() {
        presenter?.didReceive(txDetailsResult: .success(request.operationData))
    }
}
