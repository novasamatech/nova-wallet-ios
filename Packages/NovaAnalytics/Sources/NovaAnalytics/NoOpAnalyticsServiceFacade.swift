import Foundation
import Operation_iOS
import NovaOperationSupport

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
