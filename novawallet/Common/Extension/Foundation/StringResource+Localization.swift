import Foundation
import RswiftResources

/// Restores the English fallback that `R.string(preferredLanguages:)` does not have.
///
/// That call path resolves through `StringResource.Source.selected`, which asks `NSLocalizedString`
/// with an empty `value:` ("Don't use developmentValue with selected bundle/locale"). The bundle is
/// already the selected language's `<lang>.lproj`, so a key that only exists in `en.lproj` is not
/// looked up anywhere else: the lookup returns the raw key, and the screen renders
/// `legal.consent.title`.
///
/// Translations arrive after the English key does, so every new key spends some time missing from
/// the other 13 catalogs. That is cosmetic on an ordinary screen and the app has always lived with
/// it — but not on a screen the user cannot dismiss or act on without reading it. Use these helpers
/// there; `developmentValue` is the `en.lproj` string R.swift embeds at generation time, so the
/// English catalog stays the single source of truth.
extension StringResource {
    func localizedOrDevelopmentValue() -> String {
        let value = callAsFunction()

        guard value == key.description else {
            return value
        }

        return developmentValue ?? value
    }
}

extension StringResource2 {
    func localizedOrDevelopmentValue(_ arg1: Arg1, _ arg2: Arg2) -> String {
        // A missing key resolves to the key itself, and formatting it substitutes nothing because
        // the key carries no placeholders — so the comparison holds for parametrised strings too.
        let value = callAsFunction(arg1, arg2)

        guard value == key.description else {
            return value
        }

        return formattedDevelopmentValue(arg1, arg2) ?? value
    }

    /// The `en.lproj` string formatted with the same arguments, regardless of the selected language.
    /// Useful as a second candidate when a translated string exists but no longer carries the
    /// placeholders the caller depends on.
    func formattedDevelopmentValue(_ arg1: Arg1, _ arg2: Arg2) -> String? {
        developmentValue.map { String(format: $0, arguments: [arg1, arg2]) }
    }
}
