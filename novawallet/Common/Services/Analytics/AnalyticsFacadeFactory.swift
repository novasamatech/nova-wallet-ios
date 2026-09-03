import Foundation

enum AnalyticsFacadeFactory {
    /// An accessor, not a builder. The only place in the app that touches either `.shared`,
    /// so every call site shares one lock, one call store, one session and one queue.
    static func createDefault() -> AnalyticsServiceFacadeProtocol {
        #if F_ANALYTICS
            return AnalyticsServiceFacade.shared
        #else
            return NoOpAnalyticsServiceFacade.shared
        #endif
    }
}
