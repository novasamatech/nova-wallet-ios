import Foundation
import NovaAnalytics

/// The `!F_ANALYTICS` implementation. It owns no queue, no identity and no consent state,
/// so a build without the flag cannot record, identify or transmit anything at all.
final class NoOpAnalyticsServiceFacade {
    static let shared = NoOpAnalyticsServiceFacade()

    let consent: AnalyticsConsentManagerProtocol = NoOpAnalyticsConsentManager()

    private init() {}
}

// MARK: - AnalyticsServiceFacadeProtocol

extension NoOpAnalyticsServiceFacade: AnalyticsServiceFacadeProtocol {
    func setup() {}

    func throttle() {}

    func track(_: AnalyticsEvent) {}

    func trackAndFlush(
        _: AnalyticsEvent,
        reason _: AnalyticsFlushReason,
        completion: @escaping () -> Void
    ) {
        // Still called: the caller may be holding a background-task assertion on it.
        completion()
    }

    func flush(reason _: AnalyticsFlushReason) {}
}

/// Always off, so the consent prompt is never shown and the Settings row stays hidden.
private final class NoOpAnalyticsConsentManager: AnalyticsConsentManagerProtocol {
    var isEnabled: Bool { false }

    var isAvailable: Bool { false }

    var isPromptSeen: Bool { false }

    func setEnabled(_: Bool) {}

    func markPromptSeen() {}

    func addObserver(
        with _: AnyObject,
        queue _: DispatchQueue?,
        closure _: @escaping (Bool, Bool) -> Void
    ) {}

    func removeObserver(by _: AnyObject) {}
}
