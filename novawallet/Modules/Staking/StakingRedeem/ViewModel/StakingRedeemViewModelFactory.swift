import Foundation
import CommonWallet
import SoraFoundation
import SubstrateSdk

protocol StakingRedeemViewModelFactoryProtocol {
    func createRedeemViewModel(
        controllerItem: ChainAccountResponse,
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
        controllerItem: ChainAccountResponse,
        amount: Decimal
    ) throws -> StakingRedeemViewModel {
        let formatter = formatterFactory.createInputFormatter(for: assetInfo)

        let amount = LocalizableResource { locale in
            formatter.value(for: locale).string(from: amount as NSNumber) ?? ""
        }

        let icon = try iconGenerator.generateFromAccountId(controllerItem.accountId)

        return StakingRedeemViewModel(
            senderAddress: controllerItem.toAddress() ?? "",
            senderIcon: icon,
            senderName: controllerItem.name,
            amount: amount
        )
    }
}
