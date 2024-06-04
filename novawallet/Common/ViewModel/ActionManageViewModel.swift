import UIKit

struct ActionManageViewModel {
    let icon: UIImage?
    let title: String
    let details: String?
    let isDestructive: Bool

    init(icon: UIImage? = nil, title: String, details: String? = nil, isDestructive: Bool = false) {
        self.icon = icon
        self.title = title
        self.details = details
        self.isDestructive = isDestructive
    }
}
