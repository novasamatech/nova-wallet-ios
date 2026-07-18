import Foundation
import Foundation_iOS

extension StakingDuration {
    func localizableUnlockingString(for variant: UnstakingDurationVariant) -> LocalizableResource<String> {
        LocalizableResource { locale in
            let string = self.unlocking.value(for: variant).localizedDaysHours(for: locale)
            return "~\(string)"
        }
    }

    var localizableNominatorUnlockingString: LocalizableResource<String> {
        localizableUnlockingString(for: .nominator)
    }
}
