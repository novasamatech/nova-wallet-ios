import Foundation

final class MnemonicInternalLinkFactory: BaseInternalLinkFactory {}

extension MnemonicInternalLinkFactory: InternalLinkFactoryProtocol {
    func createInternalLink(from externalParams: ExternalUniversalLink.Params) -> URL? {
        guard
            let action = externalParams[ExternalUniversalLink.actionKey] as? String,
            action == UniversalLink.Action.create.rawValue,
            let entity = externalParams[ExternalUniversalLink.entityKey] as? String,
            entity == UniversalLink.Entity.wallet.rawValue,
            let mnemonic = externalParams[ImportWalletUrlParsingService.Key.mnemonic] as? String else {
            return nil
        }

        let url = baseUrl
            .appendingPathComponent(UniversalLink.Action.create.rawValue)
            .appendingPathComponent(UniversalLink.Entity.wallet.rawValue)

        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return nil
        }

        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: UniversalLink.WalletEntity.QueryKey.mnemonic, value: mnemonic)
        ]

        let otherParamKeys: [String] = [
            UniversalLink.WalletEntity.QueryKey.type,
            UniversalLink.WalletEntity.QueryKey.substrateDp,
            UniversalLink.WalletEntity.QueryKey.evmDp
        ]

        for key in otherParamKeys {
            if let param = externalParams[key] as? String {
                queryItems.append(URLQueryItem(name: key, value: param))
            }
        }

        components.queryItems = queryItems

        return components.url
    }
}
