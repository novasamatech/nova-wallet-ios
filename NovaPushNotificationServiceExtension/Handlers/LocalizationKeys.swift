import Foundation

enum LocalizationKeys {
    enum Transfer {
        static let incomeTitle = "push.notification.receive.tokens.title"
        static let outcomeTitle = "push.notification.sent.tokens.title"
        static let incomeSubtitle = "push.notification.receive.tokens.subtitle"
        static let outcomeSubtitle = "push.notification.sent.tokens.subtitle"
    }

    enum Governance {
        static let newReferendumTitle = "push.notification.new.referendum.title"
        static let newReferendumSubtitle = "push.notification.new.referendum.subtitle"
        static let referendumApprovedTitle = "push.notification.referendum.approved.title"
        static let referendumApprovedSubitle = "push.notification.referendum.approved.subtitle"
        static let referendumRejectedTitle = "push.notification.referendum.rejected.title"
        static let referendumRejectedSubitle = "push.notification.referendum.rejected.subtitle"
        static let referendumStatusUpdatedTitle = "push.notification.referendum.status.updated.title"
        static let referendumStatusUpdatedSubitle = "push.notification.referendum.status.updated.subtitle"
    }

    enum Technical {
        static let newReleaseTitle = "push.notification.new.release.title"
        static let newReleaseSubtitle = "push.notification.new.release.subtitle"
    }
}

func localizedString(_ string: String, with arguments: [CVarArg] = [], locale: Locale?) -> String {
    let bundle = localizedBundle(locale: locale)
    let localizedString = NSLocalizedString(string, bundle: bundle, comment: "")
    return String(format: localizedString, arguments: arguments)
}

func localizedBundle(locale: Locale?) -> Bundle {
    if let locale {
        if let preferredLocale = Bundle.preferredLocalizations(
            from: Bundle.main.localizations,
            forPreferences: locale.rLanguages
        ).first {
            if let path = Bundle.main.path(forResource: preferredLocale, ofType: "lproj") {
                if let bundle = Bundle(path: path) {
                    return bundle
                }
            }
        }
    }
    return Bundle.main
}
