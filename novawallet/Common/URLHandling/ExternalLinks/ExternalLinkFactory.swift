import Foundation

final class ExternalLinkFactory: UniversalLinkFactoryProtocol {
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

    func createUrlForStaking() -> URL? {
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

    func createUrlForGift(
        seed: String,
        chainId: ChainModel.Id,
        symbol: AssetModel.Symbol
    ) -> URL? {
        var urlComponents = URLComponents(url: baseUrl, resolvingAgainstBaseURL: false)

        let path: String = [
            UniversalLink.Action.open.rawValue,
            UniversalLink.Screen.gift.rawValue
        ].joined(with: .slash)

        let shortChainIdLength = 6

        let endIndex: String.Index = chainId.count < shortChainIdLength
            ? chainId.endIndex
            : chainId.index(chainId.startIndex, offsetBy: shortChainIdLength)

        let shortChainId = chainId[chainId.startIndex ..< endIndex]

        let data = "\(seed)_\(shortChainId)_\(symbol)"

        let queryItems: [URLQueryItem] = [
            URLQueryItem(
                name: ExternalUniversalLinkKey.data.rawValue,
                value: data
            )
        ]

        urlComponents?.path = "/\(path)"
        urlComponents?.queryItems = queryItems

        return urlComponents?.url
    }
}
