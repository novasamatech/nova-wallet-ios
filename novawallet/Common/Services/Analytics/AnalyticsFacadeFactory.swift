import Foundation
import NovaAnalytics

enum AnalyticsFacadeFactory {
    /// An accessor, not a builder. The only place in the app that touches either `.shared`,
    /// so every call site shares one lock, one call store, one session and one queue.
    ///
    /// The `-UNITTEST` check mirrors `AppDelegate.isUnitTesting`. Without it, enabling
    /// `F_ANALYTICS` for Debug makes every `xcodebuild test` run build the real facade, which
    /// opens the developer's actual `UserDataStorageFacade.shared` store, records a session
    /// and POSTs to the live gateway.
    static func createDefault() -> AnalyticsServiceFacadeProtocol {
        #if F_ANALYTICS
            guard !ProcessInfo.processInfo.arguments.contains("-UNITTEST") else {
                return NoOpAnalyticsServiceFacade.shared
            }

            return AnalyticsServiceFacade.shared
        #else
            return NoOpAnalyticsServiceFacade.shared
        #endif
    }
}
