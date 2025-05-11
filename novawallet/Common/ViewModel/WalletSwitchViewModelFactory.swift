import Foundation
import SubstrateSdk

protocol WalletSwitchViewModelFactoryProtocol {
    func createViewModel(from wallet: MetaAccountModel, hasNotification: Bool) -> WWalletSwitchViewModel
}

final class WalletSwitchViewModelFactory {
    private lazy var iconGenerator = NovaIconGenerator()

    // TODO: get rid of it
    func createViewModel(
        from identifier: String,
        walletIdenticon: Data?,
        walletType: MetaAccountModelType,
        hasNotification: Bool
    ) -> WalletSwitchViewModel {
        let icon = walletIdenticon.flatMap { try? iconGenerator.generateFromAccountId($0) }

        return WalletSwitchViewModel(
            identifier: identifier,
            type: WalletsListSectionViewModel.SectionType(walletType: walletType),
            iconViewModel: icon.map { DrawableIconViewModel(icon: $0) },
            hasNotification: hasNotification
        )
    }
}

extension WalletSwitchViewModelFactory: WalletSwitchViewModelFactoryProtocol {
    func createViewModel(from wallet: MetaAccountModel, hasNotification: Bool) -> WWalletSwitchViewModel {
        WWalletSwitchViewModel(
            name: wallet.name,
            type: wallet.type,
            hasNotification: hasNotification
        )
    }
}
