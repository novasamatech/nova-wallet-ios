import Foundation

protocol MythosStakingValidationFactoryProtocol: CollatorStakingValidatorFactoryProtocol {
    func noUnclaimedRewards(
        _ hasUnclaimedRewards: Bool,
        claimAction: @escaping () -> Void,
        locale: Locale
    ) -> DataValidating
}
