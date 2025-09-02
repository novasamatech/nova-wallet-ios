import Foundation
import BigInt
import Operation_iOS
import SwiftRLP
import SubstrateSdk

final class DAppEthereumConfirmInteractor: DAppOperationBaseInteractor {
    let request: DAppOperationRequest
    let ethereumOperationFactory: EthereumOperationFactoryProtocol
    let validationProviderFactory: EvmValidationProviderFactoryProtocol
    let operationQueue: OperationQueue
    let signingWrapperFactory: SigningWrapperFactoryProtocol
    let shouldSendTransaction: Bool
    let chainId: String

    private var transaction: EthereumTransaction?
    private var ethereumService: EvmTransactionServiceProtocol?
    private var signingWrapper: SigningWrapperProtocol?
    private var lastFee: EvmFeeModel?

    init(
        chainId: String,
        request: DAppOperationRequest,
        ethereumOperationFactory: EthereumOperationFactoryProtocol,
        validationProviderFactory: EvmValidationProviderFactoryProtocol,
        operationQueue: OperationQueue,
        signingWrapperFactory: SigningWrapperFactoryProtocol,
        shouldSendTransaction: Bool
    ) {
        self.chainId = chainId
        self.request = request
        self.ethereumOperationFactory = ethereumOperationFactory
        self.validationProviderFactory = validationProviderFactory
        self.operationQueue = operationQueue
        self.signingWrapperFactory = signingWrapperFactory
        self.shouldSendTransaction = shouldSendTransaction
    }

    private func setupServices() {
        let optTransaction = try? request.operationData.map(to: EthereumTransaction.self)

        guard let transaction = optTransaction else {
            let error = DAppOperationConfirmInteractorError.extrinsicBadField(name: "root")
            presenter?.didReceive(modelResult: .failure(error))
            return
        }

        self.transaction = transaction

        guard
            let transaction = try? request.operationData.map(to: EthereumTransaction.self),
            let chainAccountId = try? AccountId(hexString: transaction.from),
            let accountResponse = request.wallet.fetchEthereum(for: chainAccountId) else {
            presenter?.didReceive(modelResult: .failure(ChainAccountFetchingError.accountNotExists))
            return
        }

        let defaultGasPriceProvider = createDefaultGasPriceProvider(for: transaction)
        let maxPriorityGasPriceProvider = createMaxPriorityGasPriceProvider(for: transaction)
        let gasLimitProvider = createGasLimitProvider(for: transaction)
        let nonceProvider = createNonceProvider(for: transaction)

        ethereumService = EvmTransactionService(
            accountId: chainAccountId,
            operationFactory: ethereumOperationFactory,
            maxPriorityGasPriceProvider: maxPriorityGasPriceProvider,
            defaultGasPriceProvider: defaultGasPriceProvider,
            gasLimitProvider: gasLimitProvider,
            nonceProvider: nonceProvider,
            chainFormat: .ethereum,
            evmChainId: chainId,
            operationQueue: operationQueue
        )

        signingWrapper = signingWrapperFactory.createSigningWrapper(for: accountResponse)
    }

    private func createBuilderClosure(for transaction: EthereumTransaction) -> EvmTransactionBuilderClosure {
        { builder in

            var currentBuilder = builder

            if let dataHex = transaction.data {
                guard let data = try? Data(hexString: dataHex) else {
                    throw DAppOperationConfirmInteractorError.extrinsicBadField(name: "data")
                }

                currentBuilder = currentBuilder.usingTransactionData(data)
            }

            if let value = transaction.value {
                guard let valueInt = BigUInt.fromHexString(value) else {
                    throw DAppOperationConfirmInteractorError.extrinsicBadField(name: "value")
                }

                currentBuilder = currentBuilder.sendingValue(valueInt)
            }

            if let receiver = transaction.to {
                currentBuilder = currentBuilder.toAddress(receiver)
            }

            return currentBuilder
        }
    }

    private func createGasLimitProvider(for transaction: EthereumTransaction) -> EvmGasLimitProviderProtocol {
        if let gasLimit = transaction.gas, let value = try? BigUInt(hex: gasLimit), value > 0 {
            return EvmConstantGasLimitProvider(value: value)
        } else {
            return EvmDefaultGasLimitProvider(operationFactory: ethereumOperationFactory)
        }
    }

    private func createDefaultGasPriceProvider(
        for transaction: EthereumTransaction
    ) -> EvmGasPriceProviderProtocol {
        if let gasPrice = transaction.gasPrice, let value = try? BigUInt(hex: gasPrice), value > 0 {
            return EvmConstantGasPriceProvider(value: value)
        } else {
            return EvmLegacyGasPriceProvider(operationFactory: ethereumOperationFactory)
        }
    }

    private func createMaxPriorityGasPriceProvider(
        for transaction: EthereumTransaction
    ) -> EvmGasPriceProviderProtocol {
        if let gasPrice = transaction.gasPrice, let value = try? BigUInt(hex: gasPrice), value > 0 {
            return EvmConstantGasPriceProvider(value: value)
        } else {
            return EvmMaxPriorityGasPriceProvider(operationFactory: ethereumOperationFactory)
        }
    }

    private func createNonceProvider(for transaction: EthereumTransaction) -> EvmNonceProviderProtocol {
        if let nonce = transaction.nonce, let value = BigUInt.fromHexString(nonce) {
            return EvmConstantNonceProvider(value: value)
        } else {
            return EvmDefaultNonceProvider(operationFactory: ethereumOperationFactory)
        }
    }

    private func provideConfirmationModel(for transaction: EthereumTransaction) {
        guard let chainAccountId = try? Data(hexString: transaction.from) else {
            presenter?.didReceive(feeResult: .failure(ChainAccountFetchingError.accountNotExists))
            return
        }

        let model = DAppOperationConfirmModel(
            accountName: request.wallet.name,
            walletIdenticon: request.wallet.walletIdenticonData(),
            chainAccountId: chainAccountId,
            chainAddress: transaction.from,
            feeAsset: nil,
            dApp: request.dApp,
            dAppIcon: request.dAppIcon
        )

        presenter?.didReceive(modelResult: .success(model))
    }

    private func provideFeeModel(
        for transaction: EthereumTransaction,
        service: EvmTransactionServiceProtocol,
        validationProviderFactory: EvmValidationProviderFactoryProtocol
    ) {
        lastFee = nil

        service.estimateFee(createBuilderClosure(for: transaction), runningIn: .main) { [weak self] result in
            switch result {
            case let .success(model):
                self?.lastFee = model
                let validationProvider = validationProviderFactory.createGasPriceValidation(for: model)
                let feeModel = FeeOutputModel(
                    value: ExtrinsicFee(amount: model.fee, payer: nil, weight: .zero),
                    validationProvider: validationProvider
                )

                self?.presenter?.didReceive(feeResult: .success(feeModel))
            case let .failure(error):
                self?.presenter?.didReceive(feeResult: .failure(error))
            }
        }
    }

    private func confirmSend(
        for transaction: EthereumTransaction,
        price: EvmTransactionPrice,
        service: EvmTransactionServiceProtocol,
        signer: SigningWrapperProtocol
    ) {
        service.submit(
            createBuilderClosure(for: transaction),
            price: price,
            signer: signer,
            runningIn: .main
        ) { [weak self] result in
            guard let self = self else {
                return
            }

            do {
                switch result {
                case let .success(txHash):
                    let txHashData = try Data(hexString: txHash)
                    let response = DAppOperationResponse(signature: txHashData, modifiedTransaction: nil)
                    let result: Result<DAppOperationResponse, Error> = .success(response)
                    self.presenter?.didReceive(responseResult: result, for: self.request)
                case let .failure(error):
                    throw error
                }
            } catch {
                let result: Result<DAppOperationResponse, Error> = .failure(error)
                self.presenter?.didReceive(responseResult: result, for: self.request)
            }
        }
    }

    private func confirmSign(
        for transaction: EthereumTransaction,
        price: EvmTransactionPrice,
        service: EvmTransactionServiceProtocol,
        signer: SigningWrapperProtocol
    ) {
        service.sign(
            createBuilderClosure(for: transaction),
            price: price,
            signer: signer,
            runningIn: .main
        ) { [weak self] result in
            guard let self = self else {
                return
            }

            do {
                switch result {
                case let .success(signedTransaction):
                    let response = DAppOperationResponse(signature: signedTransaction, modifiedTransaction: nil)
                    let result: Result<DAppOperationResponse, Error> = .success(response)
                    self.presenter?.didReceive(responseResult: result, for: self.request)
                case let .failure(error):
                    throw error
                }
            } catch {
                let result: Result<DAppOperationResponse, Error> = .failure(error)
                self.presenter?.didReceive(responseResult: result, for: self.request)
            }
        }
    }
}

extension DAppEthereumConfirmInteractor: DAppOperationConfirmInteractorInputProtocol {
    func setup() {
        setupServices()

        guard
            let transaction = transaction,
            let ethereumService = ethereumService else {
            return
        }

        provideConfirmationModel(for: transaction)
        provideFeeModel(
            for: transaction,
            service: ethereumService,
            validationProviderFactory: validationProviderFactory
        )
    }

    func estimateFee() {
        guard
            let transaction = transaction,
            let ethereumService = ethereumService else {
            return
        }

        provideFeeModel(
            for: transaction,
            service: ethereumService,
            validationProviderFactory: validationProviderFactory
        )
    }

    func confirm() {
        guard
            let transaction = transaction,
            let ethereumService = ethereumService,
            let signer = signingWrapper else {
            presenter?.didReceive(modelResult: .failure(CommonError.dataCorruption))
            return
        }

        guard let feeModel = lastFee else {
            presenter?.didReceive(feeResult: .failure(CommonError.dataCorruption))
            return
        }

        let txPrice = EvmTransactionPrice(gasLimit: feeModel.gasLimit, gasPrice: feeModel.gasPrice)

        if shouldSendTransaction {
            confirmSend(for: transaction, price: txPrice, service: ethereumService, signer: signer)
        } else {
            confirmSign(for: transaction, price: txPrice, service: ethereumService, signer: signer)
        }
    }

    func reject() {
        let response = DAppOperationResponse(signature: nil, modifiedTransaction: nil)
        presenter?.didReceive(responseResult: .success(response), for: request)
    }

    func prepareTxDetails() {
        presenter?.didReceive(txDetailsResult: .success(request.operationData))
    }
}
