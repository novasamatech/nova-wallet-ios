import UIKit

enum ExperimentalOption: Int, CaseIterable {
    case signer
    case notifications
}

extension ExperimentalOption {
    func title(for locale: Locale) -> String {
        switch self {
        case .notifications:
            return R.string.localizable.experimentalOptionNotifications(preferredLanguages: locale.rLanguages)
        case .signer:
            return R.string.localizable.experimentalOptionSigners(preferredLanguages: locale.rLanguages)
        }
    }

    var icon: UIImage? {
        switch self {
        case .notifications:
            return R.image.iconDefaultDapp()!
        case .signer:
            return R.image.iconDefaultDapp()!
        }
    }
}
