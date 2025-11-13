import Foundation

// MARK: - Link Factory

protocol GiftLinkFactoryProtocol {
    func createExternalLink(
        using seed: String,
        chainId: ChainModel.Id,
        symbol: AssetModel.Symbol
    ) -> URL?
}

final class GiftLinkFactory {
    let baseUrl: URL

    init(baseUrl: URL) {
        self.baseUrl = baseUrl
    }
}

// MARK: - Private

private extension GiftLinkFactory {
    func createPayloadChainId(from chainId: ChainModel.Id) -> String? {
        guard chainId != Constants.defaultChainId else { return nil }

        let shortChainIdLength = Constants.shortChainIdMaxLength
        let endIndex: String.Index = chainId.count < shortChainIdLength
            ? chainId.endIndex
            : chainId.index(chainId.startIndex, offsetBy: shortChainIdLength)

        return String(chainId[chainId.startIndex ..< endIndex])
    }

    func createPayloadAssetSymbol(
        from symbol: AssetModel.Symbol,
        chainId: ChainModel.Id
    ) -> String? {
        let defaultChainAssetGift = symbol == Constants.defaultAsset && chainId == Constants.defaultChainId

        guard !defaultChainAssetGift else { return nil }

        return symbol
    }
}

// MARK: - GiftLinkFactoryProtocol

extension GiftLinkFactory: GiftLinkFactoryProtocol {
    func createExternalLink(
        using seed: String,
        chainId: ChainModel.Id,
        symbol: AssetModel.Symbol
    ) -> URL? {
        var urlComponents = URLComponents(url: baseUrl, resolvingAgainstBaseURL: false)

        let payloadSymbol = createPayloadAssetSymbol(
            from: symbol,
            chainId: chainId
        )

        let payloadChainId = createPayloadChainId(from: chainId)

        let payload = [
            seed,
            payloadSymbol,
            payloadChainId
        ].compactMap { $0 }.joined(with: .underscore)

        let queryItems: [URLQueryItem] = [
            URLQueryItem(
                name: ExternalUniversalLinkKey.action.rawValue,
                value: UniversalLink.Action.open.rawValue
            ),
            URLQueryItem(
                name: ExternalUniversalLinkKey.screen.rawValue,
                value: UniversalLink.Screen.gift.rawValue
            ),
            URLQueryItem(
                name: UniversalLink.Gift.QueryKey.payload,
                value: payload
            )
        ]

        urlComponents?.queryItems = queryItems

        return urlComponents?.url
    }
}

// MARK: - Payload parsing

protocol GiftLinkPayloadParserProtocol {
    func parseLinkPayload(
        payloadString: String
    ) -> GiftSharingPayload?
}

final class GiftLinkPayloadParser: GiftLinkPayloadParserProtocol {
    func parseLinkPayload(
        payloadString: String
    ) -> GiftSharingPayload? {
        let rawPayloadComponents = payloadString.split(by: .underscore)

        guard rawPayloadComponents.count <= 3 else {
            return nil
        }

        guard rawPayloadComponents.count > 1 else {
            return GiftSharingPayload(
                seed: rawPayloadComponents[0],
                chainId: Constants.defaultChainId[0 ..< Constants.shortChainIdMaxLength],
                assetSymbol: Constants.defaultAsset
            )
        }

        guard rawPayloadComponents.count > 2 else {
            return GiftSharingPayload(
                seed: rawPayloadComponents[0],
                chainId: Constants.defaultChainId[0 ..< Constants.shortChainIdMaxLength],
                assetSymbol: rawPayloadComponents[1]
            )
        }

        return GiftSharingPayload(
            seed: rawPayloadComponents[0],
            chainId: rawPayloadComponents[2],
            assetSymbol: rawPayloadComponents[1]
        )
    }
}

// MARK: - Constants

private enum Constants {
    static let defaultChainId = KnowChainId.polkadotAssetHub
    static let defaultAsset = "DOT"
    static let shortChainIdMaxLength = 6
}
