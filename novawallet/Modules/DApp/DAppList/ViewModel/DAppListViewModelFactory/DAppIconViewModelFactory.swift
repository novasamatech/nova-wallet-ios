import Foundation

protocol DAppIconViewModelFactoryProtocol {
    func createIconViewModel(for favorite: DAppFavorite) -> ImageViewModelProtocol
    func createIconViewModel(for dApp: DApp) -> ImageViewModelProtocol
}

class DAppIconViewModelFactory {
    private let faviconAPIURLString: String = "https://icons.duckduckgo.com/ip3"
    private let faviconExtension: String = "ico"
}

// MARK: Private

private extension DAppIconViewModelFactory {
    func createFaviconURL(for pageURL: URL) -> URL? {
        guard let domain = pageURL.host else { return nil }

        let resultURLString = [
            [
                faviconAPIURLString,
                domain
            ].joined(with: .slash),

            faviconExtension
        ].joined(with: .dot)

        return URL(string: resultURLString)
    }

    func createImageViewModel(
        for iconURL: URL?,
        dAppURL: URL
    ) -> ImageViewModelProtocol {
        if let iconURL {
            RemoteImageViewModel(url: iconURL)
        } else if let faviconURL = createFaviconURL(for: dAppURL) {
            RemoteImageViewModel(url: faviconURL)
        } else {
            StaticImageViewModel(image: R.image.iconDefaultDapp()!)
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
}
