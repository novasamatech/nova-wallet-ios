import Foundation

final class DAppInternalLinkFactory: BaseInternalLinkFactory {}

extension DAppInternalLinkFactory: InternalLinkFactoryProtocol {
    func createInternalLink(from externalParams: ExternalUniversalLink.Params) -> URL? {
        guard
            let action = externalParams[ExternalUniversalLink.actionKey] as? String,
            action == UniversalLink.Action.open.rawValue,
            let screen = externalParams[ExternalUniversalLink.screenKey] as? String,
            screen == UniversalLink.Screen.dApp.rawValue,
            let urlParam = externalParams[UniversalLink.DAppScreen.QueryKey.url] as? String else {
            return nil
        }

        let url = baseUrl
            .appendingPathComponent(UniversalLink.Action.open.rawValue)
            .appendingPathComponent(UniversalLink.Screen.dApp.rawValue)

        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return nil
        }

        components.queryItems = [
            URLQueryItem(name: UniversalLink.DAppScreen.QueryKey.url, value: urlParam)
        ]

        return components.url
    }
}
