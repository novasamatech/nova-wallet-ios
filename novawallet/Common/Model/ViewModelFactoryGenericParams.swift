import Foundation

struct ViewModelFactoryGenericParams {
    let locale: Locale
    let privacyModeEnabled: Bool

    init(
        locale: Locale,
        privacyModeEnabled: Bool = false
    ) {
        self.locale = locale
        self.privacyModeEnabled = privacyModeEnabled
    }
}
