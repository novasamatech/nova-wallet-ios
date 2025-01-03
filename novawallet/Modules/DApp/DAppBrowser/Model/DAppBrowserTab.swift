import Foundation
import Operation_iOS

struct DAppBrowserTab {
    let uuid: UUID
    let name: String?
    let url: URL
    let createdAt: Date
    let renderModifiedAt: Date?
    let transportStates: [DAppTransportState]?
    let desktopOnly: Bool?
    let icon: URL?

    var persistenceModel: PersistenceModel {
        PersistenceModel(
            uuid: uuid,
            name: name,
            url: url,
            createdAt: createdAt,
            renderModifiedAt: renderModifiedAt,
            icon: icon?.absoluteString,
            desktopOnly: desktopOnly
        )
    }

    init(
        uuid: UUID,
        name: String?,
        url: URL,
        createdAt: Date,
        renderModifiedAt: Date?,
        transportStates: [DAppTransportState]?,
        desktopOnly: Bool?,
        icon: URL?
    ) {
        self.uuid = uuid
        self.name = name
        self.url = url
        self.createdAt = createdAt
        self.renderModifiedAt = renderModifiedAt
        self.transportStates = transportStates
        self.desktopOnly = desktopOnly
        self.icon = icon
    }

    init?(from searchResult: DAppSearchResult) {
        switch searchResult {
        case let .query(query):
            self.init(from: query)
        case let .dApp(dApp):
            self.init(from: dApp)
        }
    }

    init?(from query: String) {
        guard let url = DAppBrowserTab.resolveUrl(for: query) else {
            return nil
        }

        uuid = UUID()
        createdAt = Date()
        renderModifiedAt = nil
        transportStates = nil
        desktopOnly = nil
        name = nil
        icon = nil
        self.url = url
    }

    init(from dApp: DApp) {
        uuid = UUID()
        createdAt = Date()
        renderModifiedAt = nil
        transportStates = nil
        desktopOnly = dApp.desktopOnly
        name = dApp.name
        url = dApp.url
        icon = dApp.icon
    }

    func updating(
        transportStates: [DAppTransportState]? = nil,
        name: String? = nil,
        desktopOnly: Bool? = nil,
        renderModifiedAt: Date? = nil,
        icon: URL? = nil
    ) -> DAppBrowserTab {
        DAppBrowserTab(
            uuid: uuid,
            name: name ?? self.name,
            url: url,
            createdAt: createdAt,
            renderModifiedAt: renderModifiedAt ?? self.renderModifiedAt,
            transportStates: transportStates ?? self.transportStates,
            desktopOnly: desktopOnly ?? self.desktopOnly,
            icon: icon ?? self.icon
        )
    }

    func updating(with searchResult: DAppSearchResult) -> DAppBrowserTab? {
        switch searchResult {
        case let .query(query):
            guard let url = DAppBrowserTab.resolveUrl(for: query) else { return nil }

            return updating(with: url)
        case let .dApp(dApp):
            return updating(with: dApp)
        }
    }

    func updating(with dApp: DApp) -> DAppBrowserTab {
        DAppBrowserTab(
            uuid: uuid,
            name: dApp.name,
            url: dApp.url,
            createdAt: createdAt,
            renderModifiedAt: renderModifiedAt,
            transportStates: nil,
            desktopOnly: dApp.desktopOnly,
            icon: dApp.icon
        )
    }

    func updating(with url: URL) -> DAppBrowserTab {
        DAppBrowserTab(
            uuid: uuid,
            name: nil,
            url: url,
            createdAt: createdAt,
            renderModifiedAt: renderModifiedAt,
            transportStates: nil,
            desktopOnly: nil,
            icon: nil
        )
    }

    static func resolveUrl(for query: String) -> URL? {
        var urlComponents = URLComponents(string: query)

        if urlComponents?.scheme == nil {
            urlComponents = URLComponents(string: "https://" + query)
        }

        let isValidUrl = NSPredicate.urlPredicate.evaluate(with: query)
        if isValidUrl, let inputUrl = urlComponents?.url {
            return inputUrl
        } else {
            let querySet = CharacterSet.urlQueryAllowed
            guard let searchQuery = query.addingPercentEncoding(withAllowedCharacters: querySet) else {
                return nil
            }

            return URL(string: "https://duckduckgo.com/?q=\(searchQuery)")
        }
    }
}

// MARK: PersistenceModel

extension DAppBrowserTab {
    struct PersistenceModel: Hashable, Equatable, Identifiable {
        var identifier: String { uuid.uuidString }

        let uuid: UUID
        let name: String?
        let url: URL
        let createdAt: Date
        let renderModifiedAt: Date?
        let icon: String?
        let desktopOnly: Bool?
    }
}

// MARK: Equatable

extension DAppBrowserTab: Equatable {
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.uuid == rhs.uuid
            && lhs.name == rhs.name
            && lhs.desktopOnly == rhs.desktopOnly
            && lhs.transportStates?.count == rhs.transportStates?.count
            && lhs.url == rhs.url
            && lhs.createdAt == rhs.createdAt
            && lhs.renderModifiedAt == rhs.renderModifiedAt
            && lhs.icon == rhs.icon
    }
}
