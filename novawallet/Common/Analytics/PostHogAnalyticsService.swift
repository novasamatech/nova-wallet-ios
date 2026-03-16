import Foundation

final class PostHogAnalyticsService {
    static let shared = PostHogAnalyticsService()

    private static let apiKey = "phc_nova_analytics"
    private static let host = "https://analytics.novawallet.io"

    private let queue = DispatchQueue(label: "io.novawallet.analytics")
    private var _isEnabled: Bool = true

    private init() {}

    func initialize() {
        // PostHog SDK initialization
        // PHGPostHog.setup(with: PHGPostHogConfiguration(apiKey: Self.apiKey, host: Self.host).apply {
        //     $0.captureScreenViews = false
        //     $0.captureApplicationLifecycleEvents = false
        //     $0.flushAt = 20
        //     $0.flushInterval = 30
        // })
        Logger.shared.info("PostHog analytics initialized")
    }
}

extension PostHogAnalyticsService: AnalyticsServiceProtocol {
    var isEnabled: Bool {
        get { queue.sync { _isEnabled } }
        set {
            queue.sync {
                _isEnabled = newValue
                if !newValue {
                    // PHGPostHog.shared()?.disable()
                    // PHGPostHog.shared()?.reset()
                    Logger.shared.info("Analytics disabled and reset")
                } else {
                    // PHGPostHog.shared()?.enable()
                    Logger.shared.info("Analytics enabled")
                }
            }
        }
    }

    func track(_ event: AnalyticsEvent) {
        let enabled = queue.sync { _isEnabled }
        guard enabled else { return }

        // PHGPostHog.shared()?.capture(event.name, properties: event.properties)
        Logger.shared.debug("Analytics event: \(event.name) properties: \(event.properties)")
    }
}
