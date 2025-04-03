import Foundation
import Foundation_iOS

extension StakingDuration {
    var localizableUnlockingString: LocalizableResource<String> {
        LocalizableResource { locale in
            let string = unlocking.localizedDaysHours(for: locale)
            return "~\(string)"
        }
    }
}
