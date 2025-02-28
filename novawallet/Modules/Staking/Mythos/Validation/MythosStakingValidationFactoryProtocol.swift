import Foundation

protocol MythosStakingValidationFactoryProtocol: CollatorStakingValidatorFactoryProtocol {
    func notExceedsMaxUnstakingItems(
        unstakingItemsCount: Int,
        maxUnstakingItemsAllowed: UInt32?,
        locale: Locale
    ) -> DataValidating
}
