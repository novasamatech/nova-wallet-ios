import UIKit
import CommonWallet
import SoraFoundation

class AssetDetailsContainingViewFactory: AccountDetailsContainingViewFactoryProtocol {
    let chainAsset: ChainAsset
    let localizationManager: LocalizationManagerProtocol

    var commandFactory: WalletCommandFactoryProtocol?

    init(
        chainAsset: ChainAsset,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.chainAsset = chainAsset
        self.localizationManager = localizationManager
    }

    func createView() -> BaseAccountDetailsContainingView {
        let view = R.nib.assetDetailsView(owner: nil)!

        let iconViewModel: WalletImageViewModelProtocol?

        let assetInfo = chainAsset.assetDisplayInfo

        if let iconUrl = assetInfo.icon {
            iconViewModel = WalletRemoteImageViewModel(
                url: iconUrl,
                size: CGSize(width: 24.0, height: 24.0)
            )
        } else {
            iconViewModel = nil
        }

        let title = LocalizableResource { _ in
            assetInfo.symbol.uppercased()
        }

        view.bind(title: title, iconViewModel: iconViewModel)
        view.localizationManager = localizationManager

        bindCommands(to: view)

        return view
    }

    private func bindCommands(to view: AssetDetailsView) {
        guard let commandFactory = commandFactory else {
            return
        }

        let assetId = chainAsset.chainAssetId.walletId
        let sendCommand: WalletCommandProtocol = commandFactory.prepareSendCommand(for: assetId)
        let receiveCommand: WalletCommandProtocol = commandFactory.prepareReceiveCommand(for: assetId)

        // TODO: Enable buy command when tokens ready
        let buyCommand: WalletCommandProtocol? = nil

        /* if let walletChain = Chain(genesisHash: chain.chainId) {
             let actions = purchaseProvider.buildPurchaseActions(for: walletChain, address: address)

             buyCommand = actions.isEmpty ? nil :
                 WalletSelectPurchaseProviderCommand(
                     actions: actions,
                     commandFactory: commandFactory
                 )
         } else {
             buyCommand = nil
         } */

        view.bindActions(send: sendCommand, receive: receiveCommand, buy: buyCommand)
    }
}
