import Foundation
import CommonWallet
import SoraUI
import SoraFoundation
import SoraKeystore

final class ReceiveConfigurator: AdaptiveDesignable {
    let receiveFactory: ReceiveViewFactory

    var commandFactory: WalletCommandFactoryProtocol? {
        get {
            receiveFactory.commandFactory
        }

        set {
            receiveFactory.commandFactory = newValue
        }
    }

    let shareFactory: AccountShareFactoryProtocol

    let assetInfo: AssetBalanceDisplayInfo

    init(
        accountId: AccountId,
        chain: ChainModel,
        assetInfo: AssetBalanceDisplayInfo,
        explorers: [ChainModel.Explorer]?,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.assetInfo = assetInfo

        receiveFactory = ReceiveViewFactory(
            accountId: accountId,
            chain: chain,
            assetInfo: assetInfo,
            explorers: explorers,
            localizationManager: localizationManager
        )

        shareFactory = AccountShareFactory(
            chain: chain,
            assetInfo: assetInfo,
            localizationManager: localizationManager
        )
    }

    func configure(builder: ReceiveAmountModuleBuilderProtocol) {
        let margin: CGFloat = 24.0
        let qrSize: CGFloat = 280.0 * designScaleRatio.width + 2.0 * margin
        let style = ReceiveStyle(
            qrBackgroundColor: .clear,
            qrMode: .scaleAspectFit,
            qrSize: CGSize(width: qrSize, height: qrSize),
            qrMargin: margin
        )

        let symbol = assetInfo.symbol.uppercased()

        let title = LocalizableResource { locale in
            R.string.localizable.walletReceiveTitleFormat(symbol, preferredLanguages: locale.rLanguages)
        }

        builder
            .with(style: style)
            .with(fieldsInclusion: [])
            .with(title: title)
            .with(viewFactory: receiveFactory)
            .with(accountShareFactory: shareFactory)
    }
}
