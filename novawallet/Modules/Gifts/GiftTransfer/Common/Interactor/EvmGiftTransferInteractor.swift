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

    override func handleAssetBalance(
        result: Result<AssetBalance?, Error>,
        accountId: AccountId,
        chainId: ChainModel.Id,
        assetId: AssetModel.Id
    ) {
        switch result {
        case let .success(optBalance):
            let balance = optBalance ??
                AssetBalance.createZero(
                    for: ChainAssetId(chainId: chainId, assetId: assetId),
                    accountId: accountId
                )

            guard asset.assetId == assetId else { return }

            presenter?.didReceiveSendingAssetSenderBalance(balance)
        case .failure:
            presenter?.didReceiveError(CommonError.databaseSubscription)
        }
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
        case let (.success(model), .claimGift(builder)):
            guard let giftTransactionFeeId = GiftTransactionFeeId(rawValue: transactionFeeId) else { return }

            let feeValue = ExtrinsicFee(amount: model.fee, payer: nil, weight: .zero)

            let amount = giftTransactionFeeId.amount.map { $0 + feeValue.amount }
            let newBuilder = builder.adding(fee: feeValue)
            estimateFee(for: amount, feeType: .createGift(newBuilder))
        case let (.success(model), .createGift(builder)):
            let feeValue = ExtrinsicFee(amount: model.fee, payer: nil, weight: .zero)

            guard let totalFee = builder
                .adding(fee: feeValue)
                .multiplied(by: 2) // We take buffer to account fee fluctuations
                .build()
            else { return }

            let totamEvmFee = EvmFeeModel(
                gasLimit: totalFee.amount / model.gasPrice,
                defaultGasPrice: model.defaultGasPrice,
                maxPriorityGasPrice: model.maxPriorityGasPrice
            )

            lastFeeModel = totamEvmFee

            let validationProvider = validationProviderFactory.createGasPriceValidation(for: totamEvmFee)
            let feeModel = FeeOutputModel(value: totalFee, validationProvider: validationProvider)

            presenter?.didReceiveFee(result: .success(feeModel))
        case let (.failure(error), _):
            presenter?.didReceiveFee(result: .failure(error))
        }
    }
}

// MARK: - Private types

extension EvmGiftTransferInteractor {
    typealias TransferType = EvmTransferCommandFactory.TransferType
}
