import Foundation

protocol WCActivityValidatorMarker: URLActivityValidator {}
protocol OldWCActivityValidatorMarker: URLActivityValidator {}
protocol RainbowWCActivityValidatorMarker: URLActivityValidator {}

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

// MARK: - Private

private extension WalletConnectUrlParsingService {
    func validateNewWC(url: URL) -> Bool {
        guard
            let newWCValidator = validators.first(where: { $0 is WCActivityValidatorMarker }),
            newWCValidator.validate(url),
            let urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false),
            let link = urlComponents.queryItems?.first(where: { $0.name == "uri" })?.value
        else { return false }

        pendingUrl.state = link

        return true
    }

    /**
     * Older version of wc send both pair and sign requests through `wc:` deeplink
     * so we additionaly check for `symKey` which is only present in pairing url
     */
    func validateOldWC(url: URL) -> Bool {
        guard
            let oldWCValidator = validators.first(where: { $0 is OldWCActivityValidatorMarker }),
            oldWCValidator.validate(url)
        else { return false }

        pendingUrl.state = url.absoluteString

        return true
    }

    func validateRainbowWC(url: URL) -> Bool {
        guard
            let rainbowWCValidator = validators.first(where: { $0 is RainbowWCActivityValidatorMarker }),
            rainbowWCValidator.validate(url),
            let urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false),
            let link = urlComponents.queryItems?.first(where: { $0.name == "uri" })?.value
        else { return false }

        pendingUrl.state = link

        return true
    }
}

// MARK: - URLHandlingServiceProtocol

extension WalletConnectUrlParsingService: URLHandlingServiceProtocol {
    func handle(url: URL) -> Bool {
        if validateNewWC(url: url) {
            true
        } else if validateOldWC(url: url) {
            true
        } else {
            validateRainbowWC(url: url)
        }
    }
}

// MARK: - Validators

extension WalletConnectUrlParsingService {
    struct RainbowWCActivityValidator: RainbowWCActivityValidatorMarker {
        func validate(_ url: URL) -> Bool {
            url.scheme == "rainbow" && url.host == "wc"
        }
    }

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
