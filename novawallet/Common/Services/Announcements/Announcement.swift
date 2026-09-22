import Foundation

struct Announcement: Equatable {
    enum Style: String {
        case info
        case warning
        case error
    }

    struct Link: Equatable {
        let url: URL
        let title: [String: String]
    }

    let chainId: ChainModel.Id?
    let style: Style
    let content: [String: String]
    let link: Link?
}

enum AnnouncementSection: String {
    case staking
}

extension Announcement {
    static let defaultContentKey = "default"

    func message(for locale: Locale) -> String? {
        content.localizedValue(for: locale)
    }
}

extension Announcement.Link {
    func title(for locale: Locale) -> String? {
        title.localizedValue(for: locale)
    }
}

private extension Dictionary where Key == String, Value == String {
    func localizedValue(for locale: Locale) -> String? {
        if let languageCode = locale.languageCode, let localized = self[languageCode] {
            return localized
        }

        return self[Announcement.defaultContentKey]
    }
}
