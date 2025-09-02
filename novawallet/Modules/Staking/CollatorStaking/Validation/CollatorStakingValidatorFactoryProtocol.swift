import Foundation
import Foundation_iOS

protocol CollatorStakingValidatorFactoryProtocol: BaseDataValidatingFactoryProtocol {
    var assetDisplayInfo: AssetBalanceDisplayInfo { get }

    var balanceViewModelFactory: BalanceViewModelFactoryProtocol { get }

    var quantityFormatter: LocalizableResource<NumberFormatter> { get }

    var collatorStakingPresentable: CollatorStakingErrorPresentable { get }

    func hasMinStake(
        amount: Decimal?,
        minStake: Balance?,
        locale: Locale
    ) -> DataValidating

    func notExceedsMaxCollators(
        currentCollators: Set<AccountId>?,
        selectedCollator: AccountId?,
        maxCollatorsAllowed: UInt32?,
        locale: Locale
    ) -> DataValidating
}
