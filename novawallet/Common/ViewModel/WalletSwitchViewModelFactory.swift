import Foundation
import SubstrateSdk

final class WalletSwitchViewModelFactory {
    private lazy var iconGenerator = NovaIconGenerator()

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
