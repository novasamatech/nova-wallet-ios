import Foundation

final class NoOpAnalyticsService: AnalyticsServiceProtocol {
    var isEnabled: Bool = false

    func track(_ event: AnalyticsEvent) {
        // No-op for tests
    }
}
