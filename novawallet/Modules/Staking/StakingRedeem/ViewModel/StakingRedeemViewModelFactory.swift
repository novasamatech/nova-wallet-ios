import Foundation
import CommonWallet
import SoraFoundation
import SubstrateSdk

protocol StakingRedeemViewModelFactoryProtocol {
    func createRedeemViewModel(
        controllerItem: AccountItem,
        amount: Decimal
    ) throws -> StakingRedeemViewModel
}

final class StakingRedeemViewModelFactory: StakingRedeemViewModelFactoryProtocol {
    let assetInfo: AssetBalanceDisplayInfo

    private lazy var formatterFactory = AssetBalanceFormatterFactory()
    private lazy var iconGenerator = PolkadotIconGenerator()

    init(assetInfo: AssetBalanceDisplayInfo) {
        self.assetInfo = assetInfo
    }

    func createRedeemViewModel(
        controllerItem: AccountItem,
        amount: Decimal
    ) throws -> StakingRedeemViewModel {
        let formatter = formatterFactory.createInputFormatter(for: assetInfo)

        let amount = LocalizableResource { locale in
            formatter.value(for: locale).string(from: amount as NSNumber) ?? ""
        }

        let icon = try iconGenerator.generateFromAddress(controllerItem.address)

        return StakingRedeemViewModel(
            senderAddress: controllerItem.address,
            senderIcon: icon,
            senderName: controllerItem.username,
            amount: amount
        )
    }
}
