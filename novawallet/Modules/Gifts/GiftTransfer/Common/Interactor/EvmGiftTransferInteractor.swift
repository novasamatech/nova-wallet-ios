import Foundation
import BigInt
import Operation_iOS

class EvmGiftTransferInteractor: GiftTransferBaseInteractor {
    let feeProxy: EvmTransactionFeeProxyProtocol
    let transactionService: EvmTransactionServiceProtocol
    let validationProviderFactory: EvmValidationProviderFactoryProtocol

    private(set) var transferType: TransferType?
    private(set) var lastFeeModel: EvmFeeModel?

    init(
        selectedAccount: ChainAccountResponse,
        chain: ChainModel,
        asset: AssetModel,
        feeProxy: EvmTransactionFeeProxyProtocol,
        transactionService: EvmTransactionServiceProtocol,
        validationProviderFactory: EvmValidationProviderFactoryProtocol,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        currencyManager: CurrencyManagerProtocol,
        operationQueue: OperationQueue
    ) {
        self.feeProxy = feeProxy
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

    func addingTransferCommand(
        to builder: EvmTransactionBuilderProtocol,
        amount: OnChainTransferAmount<BigUInt>,
        recepient: AccountAddress,
        type: TransferType
    ) throws -> (EvmTransactionBuilderProtocol, CallCodingPath?) {
        let amountValue = amount.value

        switch type {
        case .native:
            let newBuilder = try builder.nativeTransfer(to: recepient, amount: amountValue)

            return (newBuilder, CallCodingPath.evmNativeTransfer)
        case let .erc20(contract):
            let newBuilder = try builder.erc20Transfer(
                to: recepient,
                contract: contract,
                amount: amountValue
            )

            return (newBuilder, CallCodingPath.erc20Tranfer)
        }
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
                let (newBuilder, _) = try self?.addingTransferCommand(
                    to: builder,
                    amount: amount,
                    recepient: recepientAddress,
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
            lastFeeModel = model

            let feeValue = ExtrinsicFee(amount: model.fee, payer: nil, weight: .zero)

            guard let totalFee = builder.adding(fee: feeValue).build() else { return }

            let validationProvider = validationProviderFactory.createGasPriceValidation(for: model)
            let feeModel = FeeOutputModel(value: totalFee, validationProvider: validationProvider)

            presenter?.didReceiveFee(result: .success(feeModel))
        case let (.failure(error), _):
            presenter?.didReceiveFee(result: .failure(error))
        }
    }
}

// MARK: - Private types

extension EvmGiftTransferInteractor {
    enum TransferType {
        case native
        case erc20(AccountAddress)

        var transactionSource: TransactionHistoryItemSource {
            switch self {
            case .native:
                return .evmNative
            case .erc20:
                return .evmAsset
            }
        }
    }
}
