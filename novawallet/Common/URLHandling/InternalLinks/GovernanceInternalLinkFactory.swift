import Foundation

final class GovernanceInternalLinkFactory: BaseInternalLinkFactory {}

extension GovernanceInternalLinkFactory: InternalLinkFactoryProtocol {
    func createInternalLink(from externalParams: ExternalUniversalLink.Params) -> URL? {
        guard
            let action = externalParams[ExternalUniversalLink.actionKey] as? String,
            action == UniversalLink.Action.open.rawValue,
            let screen = externalParams[ExternalUniversalLink.screenKey] as? String,
            screen == UniversalLink.Screen.governance.rawValue else {
            return nil
        }

        let url = baseUrl
            .appendingPathComponent(UniversalLink.Action.open.rawValue)
            .appendingPathComponent(UniversalLink.Screen.governance.rawValue)

        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return nil
        }

        let keys = [
            UniversalLink.GovScreen.QueryKey.referendumIndex,
            UniversalLink.GovScreen.QueryKey.chainid,
            UniversalLink.GovScreen.QueryKey.governanceType
        ]

        components.queryItems = keys.compactMap { key in
            guard let param = externalParams[key] as? String else { return nil }

            return URLQueryItem(name: key, value: param)
        }

        return components.url
    }
}
