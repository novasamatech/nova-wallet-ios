import Foundation

extension CollatorStakingHintsViewModelFactoryProtocol {
    func unstakeHintForParachainDuration(
        _ duration: ParachainStakingDuration,
        locale: Locale
    ) -> String {
        unstakeHint(for: duration.unstaking, locale: locale)
    }
}
