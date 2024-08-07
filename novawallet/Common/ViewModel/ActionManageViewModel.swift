import UIKit

struct ActionManageViewModel {
    let icon: UIImage?
    let title: String
    let details: String?
    let isDestructive: Bool
    let allowsIconModification: Bool

    init(
        icon: UIImage? = nil,
        title: String,
        details: String? = nil,
        isDestructive: Bool = false,
        allowsIconModification: Bool = true
    ) {
        self.icon = icon
        self.title = title
        self.details = details
        self.isDestructive = isDestructive
        self.allowsIconModification = allowsIconModification
    }
}
