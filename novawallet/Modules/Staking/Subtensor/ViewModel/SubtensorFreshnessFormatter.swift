import Foundation

enum SubtensorFreshnessFormatter {
    static func agedHint(for stamp: SubtensorBackendStamp?, now: Date = Date(), locale: Locale) -> String? {
        guard let stamp, stamp.freshness == .stale else {
            return nil
        }

        let age = max(0, now.timeIntervalSince(stamp.asOf)).localizedDaysHoursOrFallbackMinutes(for: locale)

        return R.string(preferredLanguages: locale.rLanguages).localizable.stakingSubtensorUiFreshnessUpdatedFormat(age)
    }
}
