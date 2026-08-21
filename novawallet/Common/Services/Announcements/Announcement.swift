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

extension Array where Element == Announcement {
    func generalOnly() -> [Announcement] {
        filter { $0.chainId == nil }
    }

    func groupedByChain() -> [ChainModel.Id: Announcement] {
        reduce(into: [:]) { accum, announcement in
            guard let chainId = announcement.chainId, accum[chainId] == nil else {
                return
            }

            accum[chainId] = announcement
        }
    }

    func firstAnnouncement(for chainId: ChainModel.Id) -> Announcement? {
        first { $0.chainId == chainId }
    }
}
