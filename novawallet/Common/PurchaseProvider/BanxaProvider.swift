import Foundation
import CryptoKit
import SubstrateSdk
import SoraFoundation

final class BanxaProvider: PurchaseProviderProtocol {
    #if F_RELEASE
        let host = "https://novawallet.banxa.com"
    #else
        let host = "https://novawallet.banxa-sandbox.com"
    #endif

    private var callbackUrl: URL?
    private var colorCode: String?
    private let displayURL = "banxa.com"

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
            PurchaseAction(
                title: "Banxa",
                url: url,
                icon: R.image.iconBanxa()!,
                displayURL: displayURL
            )
        ]
    }
    
    func buildRampAction(
        for chainAsset: ChainAsset,
        accountId: AccountId
    ) -> [RampAction] {
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
        
        var paymentMethods = defaultPaymentMethods
        paymentMethods.append(.others("+5"))
        
        let action = RampAction(
            logo: R.image.banxaLogo()!,
            descriptionText: LocalizableResource { locale in
                R.string.localizable.banxaBuyActionDescription(preferredLanguages: locale.rLanguages)
            },
            fiatPaymentMethods: paymentMethods,
            url: url
        )
        
        return [action]
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
