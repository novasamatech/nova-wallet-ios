import Foundation

protocol AnalyticsOptOutManaging {
    var isAnalyticsEnabled: Bool { get set }
}

final class AnalyticsOptOutManager: AnalyticsOptOutManaging {
    private let settings: SettingsManagerProtocol
    private let analyticsService: AnalyticsServiceProtocol

    init(
        settings: SettingsManagerProtocol = SettingsManager.shared,
        analyticsService: AnalyticsServiceProtocol = PostHogAnalyticsService.shared
    ) {
        self.settings = settings
        self.analyticsService = analyticsService

        // Sync initial state
        analyticsService.isEnabled = settings.analyticsEnabled
    }

    var isAnalyticsEnabled: Bool {
        get { settings.analyticsEnabled }
        set {
            settings.analyticsEnabled = newValue
            analyticsService.isEnabled = newValue
        }
    }
}
