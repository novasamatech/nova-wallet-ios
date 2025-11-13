import Foundation
import SubstrateSdk

final class WalletsAccountsChooseViewModelFactory: WalletsListViewModelFactory {
    let selectedId: String
    let chain: ChainModel

    private lazy var accountIconGenerator = PolkadotIconGenerator()

    init(
        selectedId: String,
        chain: ChainModel,
        assetBalanceFormatterFactory: AssetBalanceFormatterFactoryProtocol,
        priceAssetInfoFactory: PriceAssetInfoFactoryProtocol,
        currencyManager: CurrencyManagerProtocol
    ) {
        self.selectedId = selectedId
        self.chain = chain

        super.init(
            assetBalanceFormatterFactory: assetBalanceFormatterFactory,
            priceAssetInfoFactory: priceAssetInfoFactory,
            currencyManager: currencyManager
        )
    }

    override func isSelected(wallet: ManagedMetaAccountModel) -> Bool {
        wallet.info.metaId == selectedId
    }

    override func createItemViewModel(
        wallet: ManagedMetaAccountModel,
        balancesCalculator _: any BalancesCalculating,
        locale: Locale
    ) -> WalletsListViewModel {
        let optWalletIcon = wallet.info.walletIdenticonData().flatMap { try? iconGenerator.generateFromAccountId($0) }
        let walletIconViewModel = optWalletIcon.map { IdentifiableDrawableIconViewModel(
            .init(icon: $0),
            identifier: wallet.info.metaId
        ) }

        let chainAccount = wallet.info.fetch(for: chain.accountRequest())

        let infoViewModel: WalletView.ViewModel.ChainAccountAddressInfo

        if
            let chainAccount,
            let address = try? chainAccount.accountId.toAddress(
                using: chain.chainFormat
            ) {
            let addressDrawableIcon = try? accountIconGenerator.generateFromAddress(address)
            let imageViewModel = addressDrawableIcon.map {
                DrawableIconViewModel(icon: $0)
            }
            infoViewModel = .address(
                DisplayAddressViewModel(
                    address: address,
                    name: nil,
                    imageViewModel: imageViewModel
                )
            )
        } else {
            infoViewModel = .warning(
                WalletView.ViewModel.WarningViewModel(
                    imageViewModel: StaticImageViewModel(image: R.image.iconWarning()!),
                    text: R.string(preferredLanguages: locale.rLanguages).localizable.accountNotFoundCaption()
                )
            )
        }

        let walletViewModel = WalletView.ViewModel(
            wallet: .init(icon: walletIconViewModel, name: wallet.info.name),
            type: .account(infoViewModel)
        )

        return WalletsListViewModel(
            identifier: wallet.identifier,
            walletViewModel: walletViewModel,
            isSelected: isSelected(wallet: wallet)
        )
    }
}
