import Foundation
import BigInt
import RobinHood

class EvmOnChainTransferInteractor: OnChainTransferBaseInteractor {
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

    let feeProxy: EvmTransactionFeeProxyProtocol
    let extrinsicService: EvmTransactionServiceProtocol

    private(set) var transferType: TransferType?

    init(
        selectedAccount: ChainAccountResponse,
        chain: ChainModel,
        asset: AssetModel,
        feeProxy: EvmTransactionFeeProxyProtocol,
        extrinsicService: EvmTransactionServiceProtocol,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        currencyManager: CurrencyManagerProtocol,
        operationQueue: OperationQueue
    ) {
        self.feeProxy = feeProxy
        self.extrinsicService = extrinsicService

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
        } else if let address = asset.typeExtras?.stringValue, (try? address.toEthereumAccountId()) != nil {
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

            feeProxy.estimateFee(
                using: extrinsicService,
                reuseIdentifier: identifier
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
        result: Result<BigUInt, Error>,
        for _: TransactionFeeId
    ) {
        switch result {
        case let .success(fee):
            presenter?.didReceiveFee(result: .success(fee))
        case let .failure(error):
            presenter?.didReceiveFee(result: .failure(error))
        }
    }
}
