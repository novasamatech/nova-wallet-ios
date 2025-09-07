import Foundation

protocol PredefinedTimeShortcutProtocol {
    func getShortcut(for timeInterval: TimeInterval, roundsDown: Bool, locale: Locale) -> String?
}

final class EverydayShortcut: PredefinedTimeShortcutProtocol {
    func getShortcut(for timeInterval: TimeInterval, roundsDown: Bool, locale: Locale) -> String? {
        let (days, hours) = timeInterval.getDaysAndHours(roundingDown: roundsDown)

        guard days == 1, hours == 0 else {
            return nil
        }

        return R.string(preferredLanguages: locale.rLanguages).localizable.commonDaysEveryday()
    }
}
