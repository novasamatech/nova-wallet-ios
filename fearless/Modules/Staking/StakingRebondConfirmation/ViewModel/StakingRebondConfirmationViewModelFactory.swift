import Foundation
import CommonWallet
import SoraFoundation
import SubstrateSdk

protocol StakingRebondConfirmationViewModelFactoryProtocol {
    func createViewModel(
        controllerItem: AccountItem,
        amount: Decimal
    ) throws -> StakingRebondConfirmationViewModel
}

final class StakingRebondConfirmationViewModelFactory: StakingRebondConfirmationViewModelFactoryProtocol {
    let assetInfo: AssetBalanceDisplayInfo

    private lazy var formatterFactory = AssetBalanceFormatterFactory()
    private lazy var iconGenerator = PolkadotIconGenerator()

    init(assetInfo: AssetBalanceDisplayInfo) {
        self.assetInfo = assetInfo
    }

    func createViewModel(
        controllerItem: AccountItem,
        amount: Decimal
    ) throws -> StakingRebondConfirmationViewModel {
        let formatter = formatterFactory.createInputFormatter(for: assetInfo)

        let amount = LocalizableResource { locale in
            formatter.value(for: locale).string(from: amount as NSNumber) ?? ""
        }

        let icon = try iconGenerator.generateFromAddress(controllerItem.address)

        return StakingRebondConfirmationViewModel(
            senderAddress: controllerItem.address,
            senderIcon: icon,
            senderName: controllerItem.username,
            amount: amount
        )
    }
}
