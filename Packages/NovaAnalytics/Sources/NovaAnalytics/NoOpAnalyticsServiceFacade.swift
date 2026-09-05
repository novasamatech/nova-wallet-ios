import Foundation
import Operation_iOS
import NovaOperationSupport

/// The implementation a host installs when analytics is compiled out. It owns no queue, no
/// identity and no consent state, so such a build cannot record, identify or transmit
/// anything at all.
public final class NoOpAnalyticsServiceFacade {
    public static let shared = NoOpAnalyticsServiceFacade()

    public let consent: AnalyticsConsentManagerProtocol = NoOpAnalyticsConsentManager()

    private init() {}
}

// MARK: - AnalyticsServiceFacadeProtocol

extension NoOpAnalyticsServiceFacade: AnalyticsServiceFacadeProtocol {
    public func setup() {}

    public func throttle() {}

    public func track(_: AnalyticsEvent) {}

    public func trackAndFlush(
        _: AnalyticsEvent,
        reason _: AnalyticsFlushReason,
        completion: @escaping () -> Void
    ) {
        // Still called: the caller may be holding a background-task assertion on it.
        completion()
    }

    public func flush(reason _: AnalyticsFlushReason) {}
}

// MARK: - AnalyticsDebugInspecting

extension NoOpAnalyticsServiceFacade: AnalyticsDebugInspecting {
    public func debugPendingEventsWrapper(count _: Int) -> CompoundOperationWrapper<[AnalyticsPendingEvent]> {
        .createWithResult([])
    }

    public func debugClearPendingEventsOperation() -> BaseOperation<Void> {
        ClosureOperation {}
    }
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
