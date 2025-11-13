import Foundation

protocol ReferendumLinkFactoryProtocol {
    func createExternalLink(
        for chainModel: ChainModel,
        referendumId: ReferendumIdLocal,
        type: GovernanceType
    ) -> URL?
}

final class ReferendumLinkFactory: ReferendumLinkFactoryProtocol {
    let baseUrl: URL

    init(baseUrl: URL) {
        self.baseUrl = baseUrl
    }

    func createExternalLink(
        for chainModel: ChainModel,
        referendumId: ReferendumIdLocal,
        type: GovernanceType
    ) -> URL? {
        var urlComponents = URLComponents(url: baseUrl, resolvingAgainstBaseURL: false)

        var queryItems: [URLQueryItem] = [
            URLQueryItem(
                name: ExternalUniversalLinkKey.action.rawValue,
                value: UniversalLink.Action.open.rawValue
            ),
            URLQueryItem(
                name: ExternalUniversalLinkKey.screen.rawValue,
                value: UniversalLink.Screen.governance.rawValue
            )
        ]

        if chainModel.chainId != UniversalLink.GovScreen.defaultChainId {
            let queryItem = URLQueryItem(
                name: UniversalLink.GovScreen.QueryKey.chainid,
                value: String(chainModel.chainId)
            )

            queryItems.append(queryItem)
        }

        let referendumQueryItem = URLQueryItem(
            name: UniversalLink.GovScreen.QueryKey.referendumIndex,
            value: String(referendumId)
        )

        queryItems.append(referendumQueryItem)

        if let urlType = UniversalLink.GovScreen.urlGovType(chainModel, type: type) {
            let typeQueryItem = URLQueryItem(
                name: UniversalLink.GovScreen.QueryKey.governanceType,
                value: String(urlType.rawValue)
            )

            queryItems.append(typeQueryItem)
        }

        urlComponents?.queryItems = queryItems

        return urlComponents?.url
    }
}
