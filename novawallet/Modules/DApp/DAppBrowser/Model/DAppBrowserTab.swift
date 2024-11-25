import Foundation
import Operation_iOS

struct DAppBrowserTab {
    let uuid: UUID
    let name: String?
    let url: URL?
    let lastModified: Date
    let transportStates: [DAppTransportState]?
    let desktopOnly: Bool?
    let icon: URL?

    var persistenceModel: PersistenceModel {
        PersistenceModel(
            uuid: uuid,
            name: name,
            url: url,
            lastModified: lastModified,
            icon: icon?.absoluteString,
            desktopOnly: desktopOnly
        )
    }

    var isBlankPage: Bool {
        url == nil
    }

    init(
        uuid: UUID,
        name: String?,
        url: URL?,
        lastModified: Date,
        transportStates: [DAppTransportState]?,
        desktopOnly: Bool?,
        icon: URL?
    ) {
        self.uuid = uuid
        self.name = name
        self.url = url
        self.lastModified = lastModified
        self.transportStates = transportStates
        self.desktopOnly = desktopOnly
        self.icon = icon
    }

    init(from searchResult: DAppSearchResult?) {
        if let searchResult {
            switch searchResult {
            case let .query(query):
                self.init(from: query)
            case let .dApp(dApp):
                self.init(from: dApp)
            }
        } else {
            self.init()
        }
    }

    init() {
        uuid = UUID()
        lastModified = Date()
        transportStates = nil
        desktopOnly = nil
        name = nil
        icon = nil
        url = nil
    }

    init(from query: String) {
        uuid = UUID()
        lastModified = Date()
        transportStates = nil
        desktopOnly = nil
        name = nil
        icon = nil
        url = DAppBrowserTab.resolveUrl(for: query)
    }

    init(from dApp: DApp) {
        uuid = UUID()
        lastModified = Date()
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
        icon: URL? = nil
    ) -> DAppBrowserTab {
        DAppBrowserTab(
            uuid: uuid,
            name: name ?? self.name,
            url: url,
            lastModified: Date(),
            transportStates: transportStates ?? self.transportStates,
            desktopOnly: desktopOnly ?? self.desktopOnly,
            icon: icon ?? self.icon
        )
    }

    func updating(with dApp: DApp) -> DAppBrowserTab {
        DAppBrowserTab(
            uuid: uuid,
            name: dApp.name,
            url: dApp.url,
            lastModified: Date(),
            transportStates: nil,
            desktopOnly: dApp.desktopOnly,
            icon: dApp.icon
        )
    }

    func updating(with url: URL?) -> DAppBrowserTab {
        DAppBrowserTab(
            uuid: uuid,
            name: nil,
            url: url,
            lastModified: Date(),
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
        let url: URL?
        let lastModified: Date
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
            && lhs.lastModified == rhs.lastModified
            && lhs.icon == rhs.icon
    }
}
