import Foundation

protocol AnalyticsConsentRecoveryScheduling {
    func schedule(after delay: TimeInterval, action: @escaping () -> Void) -> () -> Void
}

struct AnalyticsConsentRecoveryScheduler: AnalyticsConsentRecoveryScheduling {
    func schedule(after delay: TimeInterval, action: @escaping () -> Void) -> () -> Void {
        let work = DispatchWorkItem(block: action)
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + delay, execute: work)
        return { work.cancel() }
    }
}
