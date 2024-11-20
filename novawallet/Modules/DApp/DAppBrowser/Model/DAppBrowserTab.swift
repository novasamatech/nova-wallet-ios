import Foundation
import Operation_iOS

struct DAppBrowserTab {
    let uuid: UUID
    let name: String?
    let url: URL
    let lastModified: Date
    let opaqueState: [Any]?
    let stateRender: Data?
    let icon: URL?

    var persistenceModel: PersistenceModel {
        PersistenceModel(
            uuid: uuid,
            name: name,
            url: url,
            lastModified: lastModified,
            icon: icon?.absoluteString
        )
    }

    init(
        uuid: UUID,
        name: String?,
        url: URL,
        lastModified: Date,
        opaqueState: [Any]?,
        stateRender: Data?,
        icon: URL?
    ) {
        self.uuid = uuid
        self.name = name
        self.url = url
        self.lastModified = lastModified
        self.opaqueState = opaqueState
        self.stateRender = stateRender
        self.icon = icon
    }

    init?(from userInput: DAppSearchResult) {
        uuid = UUID()
        lastModified = Date()
        opaqueState = nil
        stateRender = nil

        switch userInput {
        case let .query(query):
            name = nil
            icon = nil

            guard let url = DAppBrowserTab.resolveUrl(for: query) else {
                return nil
            }

            self.url = url
        case let .dApp(dApp):
            name = dApp.name
            url = dApp.url
            icon = dApp.icon
        }
    }

    func updating(
        state: [Any]? = nil,
        name: String? = nil,
        url: URL? = nil,
        lastModified: Date? = nil,
        stateRender: Data? = nil,
        icon: URL? = nil
    ) -> DAppBrowserTab {
        DAppBrowserTab(
            uuid: uuid,
            name: name ?? self.name,
            url: url ?? self.url,
            lastModified: lastModified ?? self.lastModified,
            opaqueState: state ?? opaqueState,
            stateRender: stateRender ?? self.stateRender,
            icon: icon ?? self.icon
        )
    }

    private static func resolveUrl(for query: String) -> URL? {
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
        let url: URL
        let lastModified: Date
        let icon: String?
    }
}
