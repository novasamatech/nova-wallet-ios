import Foundation
import BigInt
import Operation_iOS

class EvmGiftTransferInteractor: GiftTransferBaseInteractor {
    let feeProxy: EvmTransactionFeeProxyProtocol
    let transactionService: EvmTransactionServiceProtocol
    let validationProviderFactory: EvmValidationProviderFactoryProtocol
    let transferCommandFactory: EvmTransferCommandFactory

    private(set) var transferType: TransferType?
    private(set) var lastFeeModel: EvmFeeModel?

    init(
        selectedAccount: ChainAccountResponse,
        chain: ChainModel,
        asset: AssetModel,
        feeProxy: EvmTransactionFeeProxyProtocol,
        transferCommandFactory: EvmTransferCommandFactory,
        transactionService: EvmTransactionServiceProtocol,
        validationProviderFactory: EvmValidationProviderFactoryProtocol,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        currencyManager: CurrencyManagerProtocol,
        operationQueue: OperationQueue
    ) {
        self.feeProxy = feeProxy
        self.transferCommandFactory = transferCommandFactory
        self.transactionService = transactionService
        self.validationProviderFactory = validationProviderFactory

        super.init(
            selectedAccount: selectedAccount,
            chain: chain,
            asset: asset,
            walletLocalSubscriptionFactory: walletLocalSubscriptionFactory,
            priceLocalSubscriptionFactory: priceLocalSubscriptionFactory,
            operationQueue: operationQueue
        )

        self.currencyManager = currencyManager
    }

    override func estimateFee(
        for amount: OnChainTransferAmount<BigUInt>,
        transactionId: GiftTransferBaseInteractor.GiftTransactionFeeId,
        recepientAccountId: AccountId
    ) {
        guard let transferType else { return }

        do {
            let recepientAddress = try recepientAccountId.toAddress(using: chain.chainFormat)

            lastFeeModel = nil

            feeProxy.estimateFee(
                using: transactionService,
                reuseIdentifier: transactionId.rawValue
            ) { [weak self] builder in
                let (newBuilder, _) = try self?.transferCommandFactory.addingTransferCommand(
                    to: builder,
                    amount: amount,
                    recipient: recepientAddress,
                    type: transferType
                ) ?? (builder, nil)

                return newBuilder
            }
        } catch {
            presenter?.didReceiveFee(result: .failure(error))
        }
    }
}

// MARK: - Private

private extension EvmGiftTransferInteractor {
    func provideMinBalance() {
        presenter?.didReceiveSendingAssetExistence(.init(minBalance: 0, isSelfSufficient: true))
    }

    func continueSetup() {
        feeProxy.delegate = self

        setupSendingAssetBalanceProvider()
        setupSendingAssetPriceProviderIfNeeded()

        provideMinBalance()

        presenter?.didCompleteSetup()
    }

    func processClaimFee(
        transactionFeeId: String,
        feeModel: EvmFeeModel,
        giftFeeDescriptionBuilder: GiftFeeDescriptionBuilder
    ) {
        guard let giftTransactionFeeId = GiftTransactionFeeId(rawValue: transactionFeeId) else { return }

        let feeValue = ExtrinsicFee(amount: feeModel.fee, payer: nil, weight: .zero)

        let amount = giftTransactionFeeId.amount.map { $0 + feeValue.amount }
        let newBuilder = giftFeeDescriptionBuilder.with(claimFee: feeValue)
        estimateFee(for: amount, feeType: .createGift(newBuilder))
    }

    func processCreateFee(
        feeModel: EvmFeeModel,
        giftFeeDescriptionBuilder: GiftFeeDescriptionBuilder
    ) {
        let feeValue = ExtrinsicFee(amount: feeModel.fee, payer: nil, weight: .zero)

        guard let giftFeeDescription = giftFeeDescriptionBuilder
            .with(createFee: feeValue)
            .build()
        else { return }

        do {
            // We take buffer to account possible fee fluctuations
            let totalFee = try giftFeeDescription.createAccumulatedFee(multiplier: 2)

            let totamEvmFee = EvmFeeModel(
                gasLimit: totalFee.amount / feeModel.gasPrice,
                defaultGasPrice: feeModel.defaultGasPrice,
                maxPriorityGasPrice: feeModel.maxPriorityGasPrice
            )

            lastFeeModel = totamEvmFee

            let validationProvider = validationProviderFactory.createGasPriceValidation(for: totamEvmFee)
            let feeModel = FeeOutputModel(value: totalFee, validationProvider: validationProvider)

            presenter?.didReceiveFee(result: .success(feeModel))
        } catch {
            logger.error("Error calculating accumulated fee: \(error)")
        }
    }
}

extension EvmGiftTransferInteractor {
    func setup() {
        if asset.isEvmNative {
            transferType = .native

            continueSetup()
        } else if let address = asset.evmContractAddress, (try? address.toEthereumAccountId()) != nil {
            transferType = .erc20(address)

            continueSetup()
        } else {
            transferType = nil
            presenter?.didReceiveError(AccountAddressConversionError.invalidEthereumAddress)
        }
    }
}

extension EvmGiftTransferInteractor: EvmTransactionFeeProxyDelegate {
    func didReceiveFee(
        result: Result<EvmFeeModel, Error>,
        for transactionFeeId: TransactionFeeId
    ) {
        guard let feeType = pendingFees[transactionFeeId] else { return }

        pendingFees[transactionFeeId] = nil

        switch (result, feeType) {
        case let (.success(fee), .claimGift(builder)):
            processClaimFee(
                transactionFeeId: transactionFeeId,
                feeModel: fee,
                giftFeeDescriptionBuilder: builder
            )
        case let (.success(fee), .createGift(builder)):
            processCreateFee(
                feeModel: fee,
                giftFeeDescriptionBuilder: builder
            )
        case let (.failure(error), _):
            presenter?.didReceiveFee(result: .failure(error))
        }
    }
}

// MARK: - Private types

extension EvmGiftTransferInteractor {
    typealias TransferType = EvmTransferCommandFactory.TransferType
}
