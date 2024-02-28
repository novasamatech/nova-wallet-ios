import Foundation

final class WalletConnectUrlParsingService {
    private(set) var pendingUrl: Observable<String?> = Observable(state: nil)
}

extension WalletConnectUrlParsingService: URLHandlingServiceProtocol {
    func handle(url: URL) -> Bool {
        let newLinkMatch = url.scheme == "novawallet" && url.host == "wc"

        if newLinkMatch {
            guard
                let urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false),
                let link = urlComponents.queryItems?.first(where: { $0.name == "uri" })?.value else {
                return false
            }

            pendingUrl.state = link

            return true
        }

        /**
         * Older version of wc send both pair and sign requests through `wc:` deeplink
         * so we additionaly check for `symKey` which is only present in pairing url
         */
        let oldLinkMatch = url.scheme == "wc" && url.absoluteString.contains(substring: "symKey")

        if oldLinkMatch {
            pendingUrl.state = url.absoluteString

            return true
        }

        return false
    }
}
