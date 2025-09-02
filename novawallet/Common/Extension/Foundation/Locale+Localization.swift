import Foundation
import Foundation_iOS

extension Locale {
    var rLanguages: [String]? {
        [identifier]
    }

    var languageCodeOrEn: String {
        languageCode ?? "en"
    }
}

extension Localizable {
    var selectedLocale: Locale { localizationManager?.selectedLocale ?? Locale.current }
}
