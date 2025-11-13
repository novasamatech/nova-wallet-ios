import Foundation

protocol StakingLinkFactoryProtocol {
    func createExternalLink() -> URL?
}

final class StakingLinkFactory: StakingLinkFactoryProtocol {
    let baseUrl: URL

    init(baseUrl: URL) {
        self.baseUrl = baseUrl
    }

    func createExternalLink() -> URL? {
        var urlComponents = URLComponents(url: baseUrl, resolvingAgainstBaseURL: false)

        let queryItems: [URLQueryItem] = [
            URLQueryItem(
                name: ExternalUniversalLinkKey.action.rawValue,
                value: UniversalLink.Action.open.rawValue
            ),
            URLQueryItem(
                name: ExternalUniversalLinkKey.screen.rawValue,
                value: UniversalLink.Screen.staking.rawValue
            )
        ]

        urlComponents?.queryItems = queryItems

        return urlComponents?.url
    }
}
