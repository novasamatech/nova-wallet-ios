import Foundation
import CommonWallet
import SoraFoundation
import SubstrateSdk

protocol StakingBondMoreConfirmViewModelFactoryProtocol {
    func createViewModel(
        controllerItem: ChainAccountResponse,
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
        controllerItem: ChainAccountResponse,
        amount: Decimal
    ) throws -> StakingBondMoreConfirmViewModel {
        let formatter = formatterFactory.createInputFormatter(for: assetInfo)

        let amount = LocalizableResource { locale in
            formatter.value(for: locale).string(from: amount as NSNumber) ?? ""
        }

        let icon = try iconGenerator.generateFromAccountId(controllerItem.accountId)

        return StakingBondMoreConfirmViewModel(
            senderAddress: controllerItem.toAddress() ?? "",
            senderIcon: icon,
            senderName: controllerItem.name,
            amount: amount
        )
    }
}
