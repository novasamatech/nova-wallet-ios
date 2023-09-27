import Foundation
import CryptoKit
import SubstrateSdk

final class BanxaProvider: PurchaseProviderProtocol {
    #if F_RELEASE
        let host = ""
    #else
        let host = "https://novawallet.banxa-sandbox.com"
    #endif

    private var callbackUrl: URL?
    private var colorCode: String?

    func with(callbackUrl: URL) -> Self {
        self.callbackUrl = callbackUrl
        return self
    }

    func buildPurchaseActions(for chainAsset: ChainAsset, accountId: AccountId) -> [PurchaseAction] {
        guard
            let banxa = chainAsset.asset.buyProviders?.banxa,
            let network = banxa.blockchain?.stringValue,
            let token = banxa.coinType?.stringValue,
            let address = try? accountId.toAddress(using: chainAsset.chain.chainFormat) else {
            return []
        }

        guard let callbackUrl = self.callbackUrl,
              let url = buildURL(
                  address: address,
                  token: token,
                  network: network,
                  callbackUrl: callbackUrl
              ) else {
            return []
        }

        return [
            PurchaseAction(title: "Banxa", url: url, icon: R.image.iconBanxa()!)
        ]
    }

    private func buildURL(
        address: AccountAddress,
        token: String,
        network: String,
        callbackUrl _: URL
    ) -> URL? {
        var components = URLComponents(string: host)

        let queryItems = [
            URLQueryItem(name: "coinType", value: token),
            URLQueryItem(name: "blockchain", value: network),
            URLQueryItem(name: "walletAddress", value: address)
        ]

        components?.queryItems = queryItems

        return components?.url
    }
}
