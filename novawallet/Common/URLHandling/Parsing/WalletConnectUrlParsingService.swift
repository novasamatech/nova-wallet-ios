import Foundation

protocol WCActivityValidatorMarker: URLActivityValidator {}
protocol OldWCActivityValidatorMarker: URLActivityValidator {}

final class WalletConnectUrlParsingService {
    private(set) var pendingUrl: Observable<String?>
    var validators: [URLActivityValidator]

    init(
        pendingUrl: Observable<String?> = Observable(state: nil),
        validators: [URLActivityValidator]
    ) {
        self.pendingUrl = pendingUrl
        self.validators = validators
    }
}

extension WalletConnectUrlParsingService {
    struct WCActivityValidator: WCActivityValidatorMarker {
        func validate(_ url: URL) -> Bool {
            url.scheme == ApplicationConfig.shared.deepLinkScheme && url.host == "wc"
        }
    }

    struct OldWCActivityValidator: OldWCActivityValidatorMarker {
        func validate(_ url: URL) -> Bool {
            url.scheme == "wc" && url.absoluteString.contains(substring: "symKey")
        }
    }
}

extension WalletConnectUrlParsingService: URLHandlingServiceProtocol {
    func handle(url: URL) -> Bool {
        let newWCValidator = validators.first(where: { $0 is WCActivityValidatorMarker })

        if newWCValidator?.validate(url) == true {
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
        let oldWCValidator = validators.first(where: { $0 is OldWCActivityValidator })

        if oldWCValidator?.validate(url) == true {
            pendingUrl.state = url.absoluteString

            return true
        }

        return false
    }
}
