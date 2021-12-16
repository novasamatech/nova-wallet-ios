import Foundation
import CommonWallet
import SoraFoundation
import SubstrateSdk
import SoraKeystore

final class ReceiveViewFactory: ReceiveViewFactoryProtocol {
    let accountId: AccountId
    let chain: ChainModel
    let assetInfo: AssetBalanceDisplayInfo
    let explorers: [ChainModel.Explorer]?
    let localizationManager: LocalizationManagerProtocol
    var designScaleRatio = CGSize(width: 1.0, height: 1.0)

    weak var commandFactory: WalletCommandFactoryProtocol?

    private lazy var iconGenerator = PolkadotIconGenerator()

    init(
        accountId: AccountId,
        chain: ChainModel,
        assetInfo: AssetBalanceDisplayInfo,
        explorers: [ChainModel.Explorer]?,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.accountId = accountId
        self.chain = chain
        self.assetInfo = assetInfo
        self.explorers = explorers
        self.localizationManager = localizationManager
    }

    func createHeaderView() -> UIView? {
        guard
            let accountIcon = try? PolkadotIconGenerator().generateFromAccountId(accountId),
            let address = try? accountId.toAddress(using: chain.chainFormat) else {
            return nil
        }

        let accountViewModel = ChainAccountViewModel(
            networkName: chain.name,
            address: address,
            accountIcon: accountIcon,
            networkIconViewModel: RemoteImageViewModel(url: assetInfo.icon ?? chain.icon)
        )

        let receiveView = ReceiveHeaderView()
        receiveView.accountControl.chainAccountView.bind(viewModel: accountViewModel)

        let locale = localizationManager.selectedLocale

        if let commandFactory = commandFactory {
            let command = WalletAccountOpenCommand(
                address: address,
                explorers: explorers,
                commandFactory: commandFactory,
                locale: locale
            )
            receiveView.actionCommand = command
        }

        let infoTitle = R.string.localizable.walletReceiveDescription_v2_2_0(
            preferredLanguages: locale.rLanguages
        )

        receiveView.infoLabel.text = infoTitle

        return receiveView
    }

    func createShareControl() -> UIControl? {
        let shareButton = TriangularedButton()
        shareButton.applyDefaultStyle()

        let locale = localizationManager.selectedLocale

        shareButton.imageWithTitleView?.title = R.string.localizable.walletReceiveShareTitle(
            preferredLanguages: locale.rLanguages
        )

        shareButton.snp.makeConstraints { make in
            make.width.equalTo(designScaleRatio.width * 280)
            make.height.equalTo(52.0)
        }

        return shareButton
    }
}
