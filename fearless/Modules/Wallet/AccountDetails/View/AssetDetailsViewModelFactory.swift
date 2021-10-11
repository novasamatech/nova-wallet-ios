import Foundation
import CommonWallet

final class AssetDetailsViewModelFactory: AccountListViewModelFactoryProtocol {
    let metaAccount: MetaAccountModel
    let chains: [ChainModel.Id: ChainModel]
    let purchaseProvider: PurchaseProviderProtocol
    let amountFormatterFactory: NumberFormatterFactoryProtocol
    let priceAsset: WalletAsset

    init(
        metaAccount: MetaAccountModel,
        chains: [ChainModel.Id: ChainModel],
        purchaseProvider: PurchaseProviderProtocol,
        amountFormatterFactory: NumberFormatterFactoryProtocol,
        priceAsset: WalletAsset
    ) {
        self.metaAccount = metaAccount
        self.chains = chains
        self.purchaseProvider = purchaseProvider
        self.amountFormatterFactory = amountFormatterFactory
        self.priceAsset = priceAsset
    }

    func createAssetViewModel(
        for asset: WalletAsset,
        balance: BalanceData,
        commandFactory: WalletCommandFactoryProtocol,
        locale: Locale
    ) -> WalletViewModelProtocol? {
        let amountFormatter = amountFormatterFactory.createTokenFormatter(for: asset)
            .value(for: locale)

        let priceFormater = amountFormatterFactory.createTokenFormatter(for: priceAsset)
            .value(for: locale)

        let decimalBalance = balance.balance.decimalValue
        let amount: String

        if let balanceString = amountFormatter.stringFromDecimal(decimalBalance) {
            amount = balanceString
        } else {
            amount = balance.balance.stringValue
        }

        let balanceContext = BalanceContext(context: balance.context ?? [:])

        let priceString = priceFormater.stringFromDecimal(balanceContext.price) ?? ""

        let totalPrice = balanceContext.price * balance.balance.decimalValue
        let totalPriceString = priceFormater.stringFromDecimal(totalPrice) ?? ""

        let priceChangeString = NumberFormatter.signedPercent
            .localizableResource()
            .value(for: locale)
            .string(from: balanceContext.priceChange as NSNumber) ?? ""

        let priceChangeViewModel = balanceContext.priceChange >= 0.0 ?
            WalletPriceChangeViewModel.goingUp(displayValue: priceChangeString) :
            WalletPriceChangeViewModel.goingDown(displayValue: priceChangeString)

        let context = BalanceContext(context: balance.context ?? [:])

        let numberFormatter = amountFormatterFactory.createDisplayFormatter(for: asset)

        let leftTitle = R.string.localizable
            .walletBalanceAvailable(preferredLanguages: locale.rLanguages)

        let rightTitle = R.string.localizable
            .walletBalanceFrozen(preferredLanguages: locale.rLanguages)

        let leftDetails = numberFormatter
            .value(for: locale)
            .stringFromDecimal(context.available) ?? ""

        let rightDetails = numberFormatter
            .value(for: locale)
            .stringFromDecimal(context.frozen) ?? ""

        let imageViewModel: WalletImageViewModelProtocol?

        if let assetId = WalletAssetId(rawValue: asset.identifier), let icon = assetId.assetIcon {
            imageViewModel = WalletStaticImageViewModel(staticImage: icon)
        } else {
            imageViewModel = nil
        }

        let title = asset.platform?.value(for: locale) ?? ""

        let infoDetailsCommand = WalletAccountInfoCommand(
            balanceContext: balanceContext,
            amountFormatter: numberFormatter,
            commandFactory: commandFactory
        )

        return AssetDetailsViewModel(
            title: title,
            imageViewModel: imageViewModel,
            amount: amount,
            price: priceString,
            priceChangeViewModel: priceChangeViewModel,
            totalVolume: totalPriceString,
            leftTitle: leftTitle,
            leftDetails: leftDetails,
            rightTitle: rightTitle,
            rightDetails: rightDetails,
            infoDetailsCommand: infoDetailsCommand
        )
    }

    func createActionsViewModel(
        for assetId: String?,
        commandFactory: WalletCommandFactoryProtocol,
        locale: Locale
    ) -> WalletViewModelProtocol? {
        guard
            let assetId = assetId,
            let chainAssetId = ChainAssetId(walletId: assetId),
            let walletAssetId = WalletAssetId(chainId: chainAssetId.chainId),
            let chain = chains[chainAssetId.chainId],
            let address = metaAccount.fetch(for: chain.accountRequest())?.toAddress(),
            let walletChain = walletAssetId.chain else {
            return nil
        }

        let sendCommand: WalletCommandProtocol = commandFactory.prepareSendCommand(for: assetId)
        let sendTitle = R.string.localizable
            .walletSendTitle(preferredLanguages: locale.rLanguages)
        let sendViewModel = WalletActionViewModel(
            title: sendTitle,
            command: sendCommand
        )

        let receiveCommand: WalletCommandProtocol = commandFactory.prepareReceiveCommand(for: assetId)

        let receiveTitle = R.string.localizable
            .walletAssetReceive(preferredLanguages: locale.rLanguages)
        let receiveViewModel = WalletActionViewModel(
            title: receiveTitle,
            command: receiveCommand
        )

        let actions = purchaseProvider.buildPurchaseActions(
            for: walletChain,
            assetId: walletAssetId,
            address: address
        )

        let buyCommand: WalletCommandProtocol?
        if !actions.isEmpty {
            buyCommand = WalletSelectPurchaseProviderCommand(actions: actions, commandFactory: commandFactory)
        } else {
            buyCommand = nil
        }

        let buyTitle = R.string.localizable.walletAssetBuy(preferredLanguages: locale.rLanguages)
        let buyViewModel = WalletDisablingAction(title: buyTitle, command: buyCommand)

        return WalletActionsViewModel(
            send: sendViewModel,
            receive: receiveViewModel,
            buy: buyViewModel
        )
    }
}
