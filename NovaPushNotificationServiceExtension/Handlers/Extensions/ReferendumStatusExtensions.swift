import Foundation

extension ReferendumStateUpdatePayload.Status {
    func description(for locale: Locale?) -> String {
        switch self {
        case .created:
            return R.string.localizable.pushNotificationReferendumCreated(preferredLanguages: locale.rLanguages)
        case .deciding:
            return R.string.localizable.pushNotificationReferendumDeciding(preferredLanguages: locale.rLanguages)
        case .confirming:
            return R.string.localizable.pushNotificationReferendumConfirming(preferredLanguages: locale.rLanguages)
        case .approved:
            return R.string.localizable.pushNotificationReferendumApproved(preferredLanguages: locale.rLanguages)
        case .rejected:
            return R.string.localizable.pushNotificationReferendumRejected(preferredLanguages: locale.rLanguages)
        case .cancelled:
            return R.string.localizable.pushNotificationReferendumCancelled(preferredLanguages: locale.rLanguages)
        case .timedOut:
            return R.string.localizable.pushNotificationReferendumTimedOut(preferredLanguages: locale.rLanguages)
        case .killed:
            return R.string.localizable.pushNotificationReferendumKilled(preferredLanguages: locale.rLanguages)
        }
    }
}
