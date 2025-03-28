import UIKit

struct ActionManageViewModel {
    let icon: UIImage?
    let title: String
    let subtitle: String?
    let details: String?
    let isDestructive: Bool
    let allowsIconModification: Bool

    init(
        icon: UIImage? = nil,
        title: String,
        subtitle: String? = nil,
        details: String? = nil,
        isDestructive: Bool = false,
        allowsIconModification: Bool = true
    ) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.details = details
        self.isDestructive = isDestructive
        self.allowsIconModification = allowsIconModification
    }
}
