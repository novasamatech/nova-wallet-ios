import Foundation

struct DAppNavigation {
    let dApp: DApp
    let requestedUrl: URL

    var searchResult: DAppSearchResult {
        if dApp.url == requestedUrl {
            return .dApp(model: dApp)
        } else {
            return .query(string: requestedUrl.absoluteString)
        }
    }
}
