import Foundation
import CryptoKit
import SubstrateSdk

final class MercuryoProvider: PurchaseProviderProtocol {
    struct Configuration {
        let baseUrl: String
        let widgetId: String
        let secret: String

        static let debug = Configuration(
            baseUrl: "https://sandbox-exchange.mrcr.io",
            widgetId: "fde83da2-2a4c-4af9-a2ca-30aead5d65a0",
            secret: MercuryoKeys.testSecretKey
        )

        static let production = Configuration(
            baseUrl: "https://exchange.mercuryo.io",
            widgetId: "07c3ca04-f4a8-4d68-a192-83a1794ba705",
            secret: MercuryoKeys.secretKey
        )
    }

    #if F_RELEASE
        let configuration: Configuration = .production
    #else
        let configuration: Configuration = .debug
    #endif

    private var callbackUrl: URL?

    func with(callbackUrl: URL) -> Self {
        self.callbackUrl = callbackUrl
        return self
    }

    func buildPurchaseActions(for chainAsset: ChainAsset, accountId: AccountId) -> [PurchaseAction] {
        guard
            chainAsset.asset.buyProviders?.mercuryo != nil,
            let address = try? accountId.toAddress(using: chainAsset.chain.chainFormat) else {
            return []
        }

        guard let callbackUrl = self.callbackUrl,
              let url = buildURL(
                  address: address,
                  token: chainAsset.asset.symbol,
                  callbackUrl: callbackUrl
              ) else {
            return []
        }

        return [
            PurchaseAction(title: "Mercuryo", url: url, icon: R.image.iconMercuryo()!)
        ]
    }

    private func buildURL(address: AccountAddress, token: String, callbackUrl: URL) -> URL? {
        guard let signatureData = [address, configuration.secret].joined().data(using: .utf8) else {
            return nil
        }
        let signature = Data(SHA512.hash(data: signatureData).makeIterator())
        var components = URLComponents(string: configuration.baseUrl)

        let queryItems = [
            URLQueryItem(name: "currency", value: token),
            URLQueryItem(name: "type", value: "buy"),
            URLQueryItem(name: "address", value: address),
            URLQueryItem(name: "return_url", value: callbackUrl.absoluteString),
            URLQueryItem(name: "widget_id", value: configuration.widgetId),
            URLQueryItem(name: "signature", value: signature.toHex())
        ]

        components?.queryItems = queryItems

        return components?.url
    }
}
