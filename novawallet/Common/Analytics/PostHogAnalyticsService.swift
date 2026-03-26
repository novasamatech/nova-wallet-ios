import Foundation
import Keystore_iOS

final class PostHogAnalyticsService {
    static let shared = PostHogAnalyticsService()

    /// Stores the source context for the next `dapp_opened` event.
    /// Set before navigating to the DApp browser; read and reset in `DAppBrowserPresenter.process(page:)`.
    private static let sourceQueue = DispatchQueue(label: "io.novafoundation.nova.analytics.source")
    private static var _lastDAppSource: String = "unknown"
    static var lastDAppSource: String {
        get { sourceQueue.sync { _lastDAppSource } }
        set { sourceQueue.sync { _lastDAppSource = newValue } }
    }

    private let queue = DispatchQueue(label: "io.novawallet.analytics")
    private var _isEnabled: Bool = false
    private var _sessionId: String = UUID().uuidString

    private var apiKey: String = ""
    private var host: String = ""

    private init() {}

    var sessionId: String {
        queue.sync { _sessionId }
    }

    func initialize() {
        // Read persisted consent before any events can fire
        let settings = SettingsManager.shared
        let config = ApplicationConfig.shared

        queue.sync {
            _isEnabled = settings.analyticsEnabled
            _sessionId = UUID().uuidString
        }

        apiKey = config.analyticsApiKey
        host = config.analyticsHost

        if apiKey.isEmpty {
            #if F_DEV
                Logger.shared.warning("Analytics API key not configured")
            #endif
            return
        }

        #if F_DEV
            Logger.shared.info("PostHog analytics initialized (enabled: \(_isEnabled))")
        #endif
    }
}

extension PostHogAnalyticsService: AnalyticsServiceProtocol {
    var isEnabled: Bool {
        get { queue.sync { _isEnabled } }
        set {
            queue.sync {
                _isEnabled = newValue
                if !newValue {
                    _sessionId = UUID().uuidString
                    #if F_DEV
                        Logger.shared.info("Analytics disabled and reset")
                    #endif
                } else {
                    #if F_DEV
                        Logger.shared.info("Analytics enabled")
                    #endif
                }
            }
        }
    }

    func track(_ event: AnalyticsEvent) {
        let (enabled, currentSessionId) = queue.sync { (_isEnabled, _sessionId) }
        guard enabled, !apiKey.isEmpty else { return }

        var props = event.properties
        props["session_id"] = currentSessionId

        // Suppress PII: prevent person profile creation and geo lookup
        props["$process_person_profile"] = false
        props["$geoip_disable"] = true
        props["$ip"] = false
        // Suppress device fingerprinting properties
        props["$device_id"] = ""
        props["$device_type"] = ""
        props["$os"] = ""
        props["$os_version"] = ""
        props["$screen_height"] = ""
        props["$screen_width"] = ""
        props["$browser"] = ""
        props["$browser_version"] = ""
        props["$locale"] = ""
        props["$timezone"] = ""
        props["$app_version"] = ""
        props["$lib"] = ""
        props["$lib_version"] = ""

        let body: [String: Any] = [
            "api_key": apiKey,
            "event": event.name,
            "distinct_id": currentSessionId,
            "properties": props,
            "ip": ""
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: body) else { return }
        guard let url = URL(string: "\(host)/capture/") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("0.0.0.0", forHTTPHeaderField: "X-Forwarded-For")
        request.httpBody = jsonData

        URLSession.shared.dataTask(with: request).resume()

        #if F_DEV
            Logger.shared.debug("Analytics event sent: \(event.name)")
        #endif
    }
}
