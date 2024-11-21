import Foundation
import Operation_iOS

struct DAppBrowserTab {
    let uuid: UUID
    let name: String?
    let url: URL?
    let lastModified: Date
    let transportStates: [DAppTransportState]?
    let stateRender: Data?
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

    init(
        uuid: UUID,
        name: String?,
        url: URL?,
        lastModified: Date,
        transportStates: [DAppTransportState]?,
        stateRender: Data?,
        desktopOnly: Bool?,
        icon: URL?
    ) {
        self.uuid = uuid
        self.name = name
        self.url = url
        self.lastModified = lastModified
        self.transportStates = transportStates
        self.stateRender = stateRender
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
        stateRender = nil
        desktopOnly = nil
        name = nil
        icon = nil
        url = nil
    }

    init(from query: String) {
        uuid = UUID()
        lastModified = Date()
        transportStates = nil
        stateRender = nil
        desktopOnly = nil
        name = nil
        icon = nil
        url = DAppBrowserTab.resolveUrl(for: query)
    }

    init(from dApp: DApp) {
        uuid = UUID()
        lastModified = Date()
        transportStates = nil
        stateRender = nil
        desktopOnly = dApp.desktopOnly
        name = dApp.name
        url = dApp.url
        icon = dApp.icon
    }

    func updating(
        transportStates: [DAppTransportState]? = nil,
        name: String? = nil,
        url: URL? = nil,
        lastModified: Date? = nil,
        stateRender: Data? = nil,
        desktopOnly: Bool? = nil,
        icon: URL? = nil
    ) -> DAppBrowserTab {
        DAppBrowserTab(
            uuid: uuid,
            name: name ?? self.name,
            url: url ?? self.url,
            lastModified: lastModified ?? self.lastModified,
            transportStates: transportStates ?? self.transportStates,
            stateRender: stateRender ?? self.stateRender,
            desktopOnly: desktopOnly ?? self.desktopOnly,
            icon: icon ?? self.icon
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
