import UIKit
import CommonWallet
import SoraFoundation

class AssetDetailsContainingViewFactory: AccountDetailsContainingViewFactoryProtocol {
    let chainAsset: ChainAsset
    let localizationManager: LocalizationManagerProtocol
    let purchaseProvider: PurchaseProviderProtocol
    let selectedAccountId: AccountId
    let selectedAccountType: MetaAccountModelType

    var commandFactory: WalletCommandFactoryProtocol?

    init(
        chainAsset: ChainAsset,
        localizationManager: LocalizationManagerProtocol,
        purchaseProvider: PurchaseProviderProtocol,
        selectedAccountId: AccountId,
        selectedAccountType: MetaAccountModelType
    ) {
        self.chainAsset = chainAsset
        self.localizationManager = localizationManager
        self.purchaseProvider = purchaseProvider
        self.selectedAccountId = selectedAccountId
        self.selectedAccountType = selectedAccountType
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
            assetInfo.symbol
        }

        view.bind(title: title, iconViewModel: iconViewModel)

        let networkName = chainAsset.chain.name

        let networkIcon = RemoteImageViewModel(url: chainAsset.chain.icon)

        view.bind(networkName: networkName, iconViewModel: networkIcon)

        view.localizationManager = localizationManager

        bindCommands(to: view)

        return view
    }

    func isTransfersEnable() -> Bool {
        if let type = chainAsset.asset.type {
            switch AssetType(rawValue: type) {
            case .statemine, .none:
                return true
            case .orml:
                if let extras = try? chainAsset.asset.typeExtras?.map(to: OrmlTokenExtras.self) {
                    return extras.transfersEnabled ?? true
                } else {
                    return false
                }
            }
        } else {
            return true
        }
    }

    private func bindCommands(to view: AssetDetailsView) {
        guard let commandFactory = commandFactory else {
            return
        }

        let assetId = chainAsset.chainAssetId.walletId
        let sendCommand: WalletCommandProtocol?

        if isTransfersEnable() {
            sendCommand = TransferSetupCommand(
                commandFactory: commandFactory,
                chainAsset: chainAsset,
                recepient: nil
            )
        } else {
            sendCommand = nil
        }

        let receiveCommand: WalletCommandProtocol
        let buyCommand: WalletCommandProtocol?

        let actions = purchaseProvider.buildPurchaseActions(
            for: chainAsset,
            accountId: selectedAccountId
        )

        switch selectedAccountType {
        case .secrets, .paritySigner:
            receiveCommand = commandFactory.prepareReceiveCommand(for: assetId)

            buyCommand = actions.isEmpty ? nil :
                WalletSelectPurchaseProviderCommand(
                    actions: actions,
                    commandFactory: commandFactory
                )
        case .ledger:
            if let assetRawType = chainAsset.asset.type, case .orml = AssetType(rawValue: assetRawType) {
                receiveCommand = NoLedgerSupportCommand(tokenName: chainAsset.asset.symbol)
                buyCommand = actions.isEmpty ? nil : NoLedgerSupportCommand(tokenName: chainAsset.asset.symbol)
            } else {
                receiveCommand = commandFactory.prepareReceiveCommand(for: assetId)

                buyCommand = actions.isEmpty ? nil :
                    WalletSelectPurchaseProviderCommand(
                        actions: actions,
                        commandFactory: commandFactory
                    )
            }

        case .watchOnly:
            receiveCommand = NoKeysCommand()
            buyCommand = actions.isEmpty ? nil : NoKeysCommand()
        }

        view.bindActions(send: sendCommand, receive: receiveCommand, buy: buyCommand)
    }
}
