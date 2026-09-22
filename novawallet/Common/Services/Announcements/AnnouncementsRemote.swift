import Foundation

struct AnnouncementsRemote: Decodable {
    let sections: [String: [AnnouncementRemote?]]

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        sections = try container.decode([String: [AnnouncementRemote?]].self)
    }
}

struct AnnouncementRemote: Decodable {
    let chainId: String?
    let style: String?
    let description: [String: String]?
    let link: AnnouncementLinkRemote?
}

struct AnnouncementLinkRemote: Decodable {
    let url: String?
    let title: [String: String]?
}

extension AnnouncementsRemote {
    func announcements(for section: AnnouncementSection) -> [Announcement] {
        let remoteItems = sections[section.rawValue] ?? []

        return remoteItems.compactMap { $0?.mapToAnnouncement() }
    }
}

private extension AnnouncementRemote {
    func mapToAnnouncement() -> Announcement? {
        guard let description, !description.isEmpty else {
            return nil
        }

        let style = style.flatMap { Announcement.Style(rawValue: $0.lowercased()) } ?? .info

        return Announcement(
            chainId: chainId,
            style: style,
            content: description,
            link: link?.mapToLink()
        )
    }
}

private extension AnnouncementLinkRemote {
    func mapToLink() -> Announcement.Link? {
        guard
            let title, !title.isEmpty,
            let url = url.flatMap({ URL(string: $0) }),
            url.scheme != nil, url.host != nil
        else {
            return nil
        }

        return Announcement.Link(url: url, title: title)
    }
}
