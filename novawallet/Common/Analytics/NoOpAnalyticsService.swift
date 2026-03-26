import Foundation

final class NoOpAnalyticsService: AnalyticsServiceProtocol {
    var isEnabled: Bool = false

    func track(_: AnalyticsEvent) {
        // No-op for tests
    }
}
