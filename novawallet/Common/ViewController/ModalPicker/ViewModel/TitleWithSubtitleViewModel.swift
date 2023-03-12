import Foundation

struct TitleWithSubtitleViewModel: Hashable {
    let title: String
    let subtitle: String

    init(title: String, subtitle: String) {
        self.title = title
        self.subtitle = subtitle
    }

    init(title: String) {
        self.title = title
        subtitle = ""
    }
}
