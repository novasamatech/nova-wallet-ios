import Foundation
import BigInt
import Operation_iOS

class EvmOnChainTransferInteractor: OnChainTransferBaseInteractor {
    typealias TransferType = EvmTransferCommandFactory.TransferType

    let feeProxy: EvmTransactionFeeProxyProtocol
    let transferCommandFactory: EvmTransferCommandFactory
    let extrinsicService: EvmTransactionServiceProtocol
    let validationProviderFactory: EvmValidationProviderFactoryProtocol

    private(set) var transferType: TransferType?
    private(set) var lastFeeModel: EvmFeeModel?

    init(
        selectedAccount: ChainAccountResponse,
        chain: ChainModel,
        asset: AssetModel,
        feeProxy: EvmTransactionFeeProxyProtocol,
        transferCommandFactory: EvmTransferCommandFactory,
        extrinsicService: EvmTransactionServiceProtocol,
        validationProviderFactory: EvmValidationProviderFactoryProtocol,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        currencyManager: CurrencyManagerProtocol,
        operationQueue: OperationQueue
    ) {
        self.feeProxy = feeProxy
        self.transferCommandFactory = transferCommandFactory
        self.extrinsicService = extrinsicService
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

    private func provideMinBalance() {
        // we don't have existential deposit for evm tokens
        presenter?.didReceiveSendingAssetExistence(.init(minBalance: 0, isSelfSufficient: true))
        presenter?.didReceiveUtilityAssetMinBalance(0)
    }

    private func continueSetup() {
        feeProxy.delegate = self

        setupSendingAssetBalanceProvider()
        setupUtilityAssetBalanceProviderIfNeeded()
        setupSendingAssetPriceProviderIfNeeded()
        setupUtilityAssetPriceProviderIfNeeded()

        provideMinBalance()

        presenter?.didCompleteSetup()
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

            if asset.assetId == assetId {
                presenter?.didReceiveSendingAssetSenderBalance(balance)
            } else if chain.utilityAssets().first?.assetId == assetId {
                presenter?.didReceiveUtilityAssetSenderBalance(balance)
            }
        case .failure:
            presenter?.didReceiveError(CommonError.databaseSubscription)
        }
    }
}

extension EvmOnChainTransferInteractor {
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

    func estimateFee(for amount: OnChainTransferAmount<BigUInt>, recepient: AccountId?) {
        do {
            let recepientAccountId = recepient ?? AccountId.nonzeroAccountId(of: chain.accountIdSize)
            let recepientAddress = try recepientAccountId.toAddress(using: chain.chainFormat)

            guard let transferType = transferType else {
                return
            }

            let identifier = String(amount.value) + "-" + recepientAccountId.toHex() + "-" + amount.name

            lastFeeModel = nil

            feeProxy.estimateFee(
                using: extrinsicService,
                reuseIdentifier: identifier
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

    func requestFeePaymentAvailability(for _: ChainAsset) {
        presenter?.didReceiveCustomAssetFeeAvailable(false)
    }

    func change(recepient: AccountId?) {
        guard let recepient = recepient else {
            return
        }

        /**
         *  We don't need to track evm balances for erc20 tokens
         *  because it is not required to have any balance to receive
         *  them nor it is required to have minimal balance for transfer
         */

        let assetZeroBalance = AssetBalance.createZero(
            for: ChainAssetId(chainId: chain.chainId, assetId: asset.assetId),
            accountId: recepient
        )

        presenter?.didReceiveSendingAssetRecepientBalance(assetZeroBalance)

        if !isUtilityTransfer, let utilityChainAssetId = chain.utilityChainAssetId() {
            let utilityZeroBalance = AssetBalance.createZero(for: utilityChainAssetId, accountId: recepient)
            presenter?.didReceiveUtilityAssetRecepientBalance(utilityZeroBalance)
        }
    }
}

extension EvmOnChainTransferInteractor: EvmTransactionFeeProxyDelegate {
    func didReceiveFee(
        result: Result<EvmFeeModel, Error>,
        for _: TransactionFeeId
    ) {
        switch result {
        case let .success(model):
            lastFeeModel = model

            let validationProvider = validationProviderFactory.createGasPriceValidation(for: model)
            let feeValue = ExtrinsicFee(amount: model.fee, payer: nil, weight: .zero)
            let feeModel = FeeOutputModel(value: feeValue, validationProvider: validationProvider)
            presenter?.didReceiveFee(result: .success(feeModel))
        case let .failure(error):
            presenter?.didReceiveFee(result: .failure(error))
        }
    }
}
