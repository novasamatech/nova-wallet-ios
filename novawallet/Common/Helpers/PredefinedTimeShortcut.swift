import Foundation

protocol PredefinedTimeShortcutProtocol {
    func getShortcut(for timeInterval: TimeInterval, locale: Locale) -> String?
}

final class EverydayShortcut: PredefinedTimeShortcutProtocol {
    func getShortcut(for timeInterval: TimeInterval, locale: Locale) -> String? {
        let days = timeInterval.daysFromSeconds

        guard days == 1 else {
            return nil
        }

        let hours = (timeInterval - TimeInterval(days).secondsFromDays).hoursFromSeconds

        guard hours == 0 else {
            return nil
        }

        return R.string.localizable.commonEveryDay(preferredLanguages: locale.rLanguages)
    }
}
