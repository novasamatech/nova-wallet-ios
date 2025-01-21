import Foundation

protocol DAppIconViewModelFactoryProtocol {
    func createIconViewModel(for favorite: DAppFavorite) -> ImageViewModelProtocol
    func createIconViewModel(for dApp: DApp) -> ImageViewModelProtocol
    func createIconViewModel(for dAppAuthRequest: DAppAuthRequest) -> ImageViewModelProtocol
    func createIconViewModel(for dAppBrowserTab: DAppBrowserTab) -> ImageViewModelProtocol
}

class DAppIconViewModelFactory {
    private let faviconAPIFormat: String

    init(faviconAPIFormat: String = Constants.ddgFaviconAPIFormat) {
        self.faviconAPIFormat = faviconAPIFormat
    }
}

// MARK: Private

private extension DAppIconViewModelFactory {
    func createFaviconURL(for pageURL: URL) -> URL? {
        let regex = try? NSRegularExpression(pattern: "(?:https?://)?([^/\\?]+)")
        let urlString = pageURL.absoluteString

        guard
            let match = regex?.firstMatch(
                in: urlString,
                range: NSRange(urlString.startIndex..., in: urlString)
            ),
            let range = Range(
                match.range(at: 1),
                in: urlString
            )
        else { return nil }

        let domain = urlString[range]

        let resultURLString = String(
            format: faviconAPIFormat,
            String(domain)
        )

        return URL(string: resultURLString)
    }

    func createImageViewModel(
        for iconURL: URL?,
        dAppURL: URL
    ) -> ImageViewModelProtocol {
        if let iconURL {
            DAppIconImageViewModel.icon(RemoteImageViewModel(url: iconURL))
        } else if let faviconURL = createFaviconURL(for: dAppURL) {
            DAppIconImageViewModel.favicon(RemoteImageViewModel(url: faviconURL))
        } else {
            DAppIconImageViewModel.icon(StaticImageViewModel(image: R.image.iconDefaultDapp()!))
        }
    }
}

// MARK: DAppIconViewModelFactoryProtocol

extension DAppIconViewModelFactory: DAppIconViewModelFactoryProtocol {
    func createIconViewModel(for favorite: DAppFavorite) -> ImageViewModelProtocol {
        guard let pageURL = URL(string: favorite.identifier) else {
            return StaticImageViewModel(image: R.image.iconDefaultDapp()!)
        }

        let iconURL: URL? = if let iconURLString = favorite.icon {
            URL(string: iconURLString)
        } else {
            nil
        }

        return createImageViewModel(
            for: iconURL,
            dAppURL: pageURL
        )
    }

    func createIconViewModel(for dApp: DApp) -> ImageViewModelProtocol {
        createImageViewModel(
            for: dApp.icon,
            dAppURL: dApp.url
        )
    }

    func createIconViewModel(for dAppAuthRequest: DAppAuthRequest) -> ImageViewModelProtocol {
        guard let dAppURL = URL(string: dAppAuthRequest.dApp) else {
            return StaticImageViewModel(image: R.image.iconDefaultDapp()!)
        }

        return createImageViewModel(
            for: dAppAuthRequest.dAppIcon,
            dAppURL: dAppURL
        )
    }

    func createIconViewModel(for dAppBrowserTab: DAppBrowserTab) -> ImageViewModelProtocol {
        createImageViewModel(
            for: dAppBrowserTab.icon,
            dAppURL: dAppBrowserTab.url
        )
    }
}

// MARK: Constants

private extension DAppIconViewModelFactory {
    enum Constants {
        static let ddgFaviconAPIFormat: String = "https://icons.duckduckgo.com/ip3/%@.ico"
    }
}
