import Foundation
import Foundation_iOS

extension Locale {
    var rLanguages: [String] {
        [identifier]
    }

    var languageCodeOrEn: String {
        languageCode ?? "en"
    }
}

extension Optional where Wrapped == Locale {
    var rLanguages: [String] {
        switch self {
        case .none:
            []
        case let .some(wrapped):
            wrapped.rLanguages
        }
    }
}

extension Localizable {
    var selectedLocale: Locale { localizationManager?.selectedLocale ?? Locale.current }
}
