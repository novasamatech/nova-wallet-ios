import Foundation
import CommonWallet
import SoraFoundation
import FearlessUtils

protocol StakingBondMoreConfirmViewModelFactoryProtocol {
    func createViewModel(
        controllerItem: AccountItem,
        amount: Decimal
    ) throws -> StakingBondMoreConfirmViewModel
}

final class StakingBondMoreConfirmViewModelFactory: StakingBondMoreConfirmViewModelFactoryProtocol {
    let assetInfo: AssetBalanceDisplayInfo

    private lazy var formatterFactory = AssetBalanceFormatterFactory()
    private lazy var iconGenerator = PolkadotIconGenerator()

    init(assetInfo: AssetBalanceDisplayInfo) {
        self.assetInfo = assetInfo
    }

    func createViewModel(
        controllerItem: AccountItem,
        amount: Decimal
    ) throws -> StakingBondMoreConfirmViewModel {
        let formatter = formatterFactory.createInputFormatter(for: assetInfo)

        let amount = LocalizableResource { locale in
            formatter.value(for: locale).string(from: amount as NSNumber) ?? ""
        }

        let icon = try iconGenerator.generateFromAddress(controllerItem.address)

        return StakingBondMoreConfirmViewModel(
            senderAddress: controllerItem.address,
            senderIcon: icon,
            senderName: controllerItem.username,
            amount: amount
        )
    }
}
