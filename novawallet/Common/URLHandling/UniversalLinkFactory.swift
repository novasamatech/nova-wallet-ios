import Foundation

protocol UniversalLinkFactoryProtocol {
    func createUrl(
        for chainModel: ChainModel,
        referendumId: ReferendumIdLocal,
        type: GovernanceType
    ) -> URL?
}

final class UniversalLinkFactory: UniversalLinkFactoryProtocol {
    let baseUrl: URL

    init(baseUrl: URL) {
        self.baseUrl = baseUrl
    }

    func createUrl(
        for chainModel: ChainModel,
        referendumId: ReferendumIdLocal,
        type: GovernanceType
    ) -> URL? {
        var urlComponents = URLComponents(url: baseUrl, resolvingAgainstBaseURL: false)
        let govScreen = UniversalLink.Screen.governance.rawValue
        urlComponents?.path = UrlHandlingAction.open(screen: govScreen).path

        var queryItems: [URLQueryItem] = []

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
                value: String(referendumId)
            )

            queryItems.append(typeQueryItem)
        }

        urlComponents?.queryItems = queryItems

        return urlComponents?.url
    }
}
