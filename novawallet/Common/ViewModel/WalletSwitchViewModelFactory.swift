import Foundation
import SubstrateSdk

final class WalletSwitchViewModelFactory {
    private lazy var iconGenerator = NovaIconGenerator()

    func createViewModel(from accountId: AccountId, walletType: MetaAccountModelType) -> WalletSwitchViewModel {
        let icon = try? iconGenerator.generateFromAccountId(accountId)

        return WalletSwitchViewModel(
            type: WalletsListSectionViewModel.SectionType(walletType: walletType),
            iconViewModel: icon.map { DrawableIconViewModel(icon: $0) }
        )
    }
}
