import Foundation
import CommonWallet
import SoraFoundation
import IrohaCrypto

struct WalletCommonConfigurator {
    let localizationManager: LocalizationManagerProtocol
    let metaAccount: MetaAccountModel
    let assets: [WalletAsset]

    init(
        localizationManager: LocalizationManagerProtocol,
        metaAccount: MetaAccountModel,
        assets: [WalletAsset]
    ) {
        self.localizationManager = localizationManager
        self.metaAccount = metaAccount
        self.assets = assets
    }

    func configure(builder: CommonWalletBuilderProtocol) {
        let language = WalletLanguage(rawValue: localizationManager.selectedLocalization)
            ?? WalletLanguage.defaultLanguage

        let decoratorFactory = WalletCommandDecoratorFactory(
            localizationManager: localizationManager,
            dataStorageFacade: SubstrateDataStorageFacade.shared
        )

        // TODO: Fix when qr coding decoding fixed
        let qrCoderFactory = WalletQRCoderFactory(
            networkType: .genericSubstrate,
            publicKey: metaAccount.substratePublicKey,
            username: metaAccount.name,
            assets: assets
        )

        let singleProviderIdFactory = WalletSingleProviderIdFactory()
        let transactionTypes = TransactionType.allCases.map { $0.toWalletType() }

        builder
            .with(language: language)
            .with(commandDecoratorFactory: decoratorFactory)
            .with(logger: Logger.shared)
            .with(transactionTypeList: transactionTypes)
            .with(amountFormatterFactory: AmountFormatterFactory())
            .with(singleProviderIdentifierFactory: singleProviderIdFactory)
            .with(qrCoderFactory: qrCoderFactory)
    }
}
