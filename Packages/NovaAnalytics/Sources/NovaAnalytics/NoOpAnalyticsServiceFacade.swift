import Foundation

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

private final class NoOpAnalyticsConsentManager: AnalyticsConsentManagerProtocol {
    var isEnabled: Bool { false }

    var isAvailable: Bool { false }

    var isPromptSeen: Bool { false }

    var isErasureOwed: Bool { false }

    func setEnabled(_: Bool) {}

    func setErasureOwed(_: Bool) {}

    func markPromptSeen() {}

    func addObserver(
        with _: AnyObject,
        queue _: DispatchQueue?,
        closure _: @escaping (Bool, Bool) -> Void
    ) {}

    func removeObserver(by _: AnyObject) {}

    func addAvailabilityObserver(
        with _: AnyObject,
        queue _: DispatchQueue?,
        closure _: @escaping (Bool) -> Void
    ) {}

    func removeAvailabilityObserver(by _: AnyObject) {}
}
