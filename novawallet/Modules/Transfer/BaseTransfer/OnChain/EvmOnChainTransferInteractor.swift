import Foundation
import BigInt

final class EvmOnChainTransferInteractor {
    weak var presenter: OnChainTransferSetupInteractorOutputProtocol?

    let selectedAccount: ChainAccountResponse
    let chain: ChainModel
    let asset: AssetModel
    let feeProxy: EvmTransactionFeeProxyProtocol
    let extrinsicService: EvmTransactionServiceProtocol
    let walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    let operationQueue: OperationQueue

    private var contractAddress: AccountAddress?

    init(
        selectedAccount: ChainAccountResponse,
        chain: ChainModel,
        asset: AssetModel,
        feeProxy: EvmTransactionFeeProxyProtocol,
        extrinsicService: EvmTransactionServiceProtocol,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        operationQueue: OperationQueue
    ) {
        self.selectedAccount = selectedAccount
        self.chain = chain
        self.asset = asset
        self.feeProxy = feeProxy
        self.extrinsicService = extrinsicService
        self.walletLocalSubscriptionFactory = walletLocalSubscriptionFactory
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.operationQueue = operationQueue
    }

    private func setupSendingAssetBalanceProvider() {
        sendingAssetProvider = subscribeToAssetBalanceProvider(
            for: selectedAccount.accountId,
            chainId: chain.chainId,
            assetId: asset.assetId
        )
    }

    private func setupUtilityAssetBalanceProviderIfNeeded() {
        if let utilityAsset = chain.utilityAssets().first {
            utilityAssetProvider = subscribeToAssetBalanceProvider(
                for: selectedAccount.accountId,
                chainId: chain.chainId,
                assetId: utilityAsset.assetId
            )
        }
    }

    private func setupSendingAssetPriceProviderIfNeeded() {
        if let priceId = asset.priceId {
            let options = DataProviderObserverOptions(
                alwaysNotifyOnRefresh: false,
                waitsInProgressSyncOnAdd: false
            )

            sendingAssetPriceProvider = subscribeToPrice(for: priceId, currency: selectedCurrency, options: options)
        } else {
            presenter?.didReceiveSendingAssetPrice(nil)
        }
    }

    private func setupUtilityAssetPriceProviderIfNeeded() {
        guard let utilityAsset = chain.utilityAssets().first else {
            return
        }

        if let priceId = utilityAsset.priceId {
            let options = DataProviderObserverOptions(
                alwaysNotifyOnRefresh: false,
                waitsInProgressSyncOnAdd: false
            )

            utilityAssetPriceProvider = subscribeToPrice(for: priceId, currency: selectedCurrency, options: options)
        } else {
            presenter?.didReceiveUtilityAssetPrice(nil)
        }
    }

    private func provideMinBalance() {
        // we don't have existential deposit for evm tokens
        presenter?.didReceiveSendingAssetExistence(.init(minBalance: 0, isSelfSufficient: true))
    }

    func addingTransferCommand(
        to builder: EvmTransactionBuilderProtocol,
        amount: OnChainTransferAmount<BigUInt>,
        recepient: AccountAddress,
        contract: AccountAddress
    ) throws -> EvmTransactionBuilderProtocol {
        let amountValue = amount.value

        return try builder.erc20Transfer(
            to: recepient,
            contract: contract,
            amount: amountValue
        )
    }
}

extension EvmOnChainTransferInteractor {
    func setup() {
        if let address = asset.typeExtras?.stringValue, (try? address.toEthereumAccountId()) != nil {
            contractAddress = address
        } else {
            contractAddress = nil
            presenter?.didReceiveError(AccountAddressConversionError.invalidEthereumAddress)
        }
    }

    func estimateFee(for amount: OnChainTransferAmount<BigUInt>, recepient: AccountId?) {
        do {
            let recepientAccountId = recepient ?? AccountId.nonzeroAccountId(of: chain.accountIdSize)
            let recepientAddress = try recepientAccountId.toAddress(using: chain.chainFormat)

            guard let contractAddress = contractAddress else {
                return
            }

            let identifier = String(amount.value) + "-" + recepientAccountId.toHex() + "-" + amount.name

            feeProxy.estimateFee(
                using: extrinsicService,
                reuseIdentifier: identifier
            ) { [weak self] builder in
                try self?.addingTransferCommand(
                    to: builder,
                    amount: amount,
                    recepient: recepientAddress,
                    contract: contractAddress
                ) ?? builder
            }
        } catch {
            presenter?.didReceiveFee(result: .failure(error))
        }
    }

    func change(recepient: AccountId?) {}
}
