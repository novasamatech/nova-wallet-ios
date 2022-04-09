import Foundation
import CommonWallet
import SoraFoundation
import SubstrateSdk

protocol StakingRebondConfirmationViewModelFactoryProtocol {
    func createViewModel(
        controllerItem: ChainAccountResponse,
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
        controllerItem: ChainAccountResponse,
        amount: Decimal
    ) throws -> StakingRebondConfirmationViewModel {
        let formatter = formatterFactory.createInputFormatter(for: assetInfo)

        let amount = LocalizableResource { locale in
            formatter.value(for: locale).string(from: amount as NSNumber) ?? ""
        }

        let icon = try iconGenerator.generateFromAccountId(controllerItem.accountId)

        return StakingRebondConfirmationViewModel(
            senderAddress: controllerItem.toAddress() ?? "",
            senderIcon: icon,
            senderName: controllerItem.name,
            amount: amount
        )
    }
}
