import Foundation
import BigInt
import RobinHood

final class DAppEthereumConfirmInteractor: DAppOperationBaseInteractor {
    let request: DAppOperationRequest
    let chain: MetamaskChain
    let ethereumOperationFactory: EthereumOperationFactoryProtocol
    let operationQueue: OperationQueue

    init(
        request: DAppOperationRequest,
        chain: MetamaskChain,
        ethereumOperationFactory: EthereumOperationFactoryProtocol,
        operationQueue: OperationQueue
    ) {
        self.request = request
        self.chain = chain
        self.ethereumOperationFactory = ethereumOperationFactory
        self.operationQueue = operationQueue
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

            guard let gas = BigUInt.fromHexString(gasHex) else {
                throw DAppOperationConfirmInteractorError.extrinsicBadField(name: "gas")
            }

            guard let gasPrice = BigUInt.fromHexString(gasPriceHex) else {
                throw DAppOperationConfirmInteractorError.extrinsicBadField(name: "gasPrice")
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
        SigningWrapper(keystore: <#T##KeystoreProtocol#>, metaId: <#T##String#>, accountId: <#T##AccountId?#>, isEthereumBased: <#T##Bool#>, cryptoType: <#T##MultiassetCryptoType#>, publicKeyData: <#T##Data#>)
    }

    func reject() {
        let response = DAppOperationResponse(signature: nil)
        presenter?.didReceive(responseResult: .success(response), for: request)
    }

    func prepareTxDetails() {
        presenter?.didReceive(txDetailsResult: .success(request.operationData))
    }
}
