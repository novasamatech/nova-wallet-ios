import Foundation
import SubstrateSdk

final class WalletSwitchViewModelFactory {
    private lazy var iconGenerator = NovaIconGenerator()

    func createViewModel(from walletIdenticon: Data?, walletType: MetaAccountModelType) -> WalletSwitchViewModel {
        let icon = walletIdenticon.flatMap { try? iconGenerator.generateFromAccountId($0) }

        return WalletSwitchViewModel(
            type: WalletsListSectionViewModel.SectionType(walletType: walletType),
            iconViewModel: icon.map { DrawableIconViewModel(icon: $0) }
        )
    }
}
