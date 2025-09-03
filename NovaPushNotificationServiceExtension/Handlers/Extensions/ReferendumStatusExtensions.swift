import Foundation

extension ReferendumStateUpdatePayload.Status {
    func description(for locale: Locale?) -> String {
        switch self {
        case .created:
            return R.string(preferredLanguages: locale.rLanguages).localizable.pushNotificationReferendumCreated()
        case .deciding:
            return R.string(preferredLanguages: locale.rLanguages).localizable.pushNotificationReferendumDeciding()
        case .confirming:
            return R.string(preferredLanguages: locale.rLanguages).localizable.pushNotificationReferendumConfirming()
        case .approved:
            return R.string(preferredLanguages: locale.rLanguages).localizable.pushNotificationReferendumApproved()
        case .rejected:
            return R.string(preferredLanguages: locale.rLanguages).localizable.pushNotificationReferendumRejected()
        case .cancelled:
            return R.string(preferredLanguages: locale.rLanguages).localizable.pushNotificationReferendumCancelled()
        case .timedOut:
            return R.string(preferredLanguages: locale.rLanguages).localizable.pushNotificationReferendumTimedOut()
        case .killed:
            return R.string(preferredLanguages: locale.rLanguages).localizable.pushNotificationReferendumKilled()
        }
    }
}
