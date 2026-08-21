import Foundation

struct Announcement: Equatable {
    enum Style: String {
        case info
        case warning
        case error
    }

    let chainId: ChainModel.Id?
    let style: Style
    let content: [String: String]
}

enum AnnouncementSection: String {
    case staking
}

extension Announcement {
    static let defaultContentKey = "default"

    func message(for locale: Locale) -> String? {
        if let languageCode = locale.languageCode, let localized = content[languageCode] {
            return localized
        }

        return content[Self.defaultContentKey]
    }
}

