import UIKit

enum ActionManageStyle {
    case available
    case unavailable
    case destructive
}

struct ActionManageViewModel {
    let icon: UIImage?
    let title: String
    let subtitle: String?
    let details: String?
    let style: ActionManageStyle
    let allowsIconModification: Bool

    init(
        icon: UIImage? = nil,
        title: String,
        subtitle: String? = nil,
        details: String? = nil,
        style: ActionManageStyle = .available,
        allowsIconModification: Bool = true
    ) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.details = details
        self.style = style
        self.allowsIconModification = allowsIconModification
    }
}
