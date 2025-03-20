import Foundation
import SoraFoundation

final class TransakProvider {
    #if F_RELEASE
        static let pubToken = "861a131b-1721-4e99-8ec3-7349840c888f"
        static let baseUrlString = "https://global.transak.com"
    #else
        static let pubToken = "ed6a6887-57fd-493a-8075-4718b463913b"
        static let baseUrlString = "https://staging-global.transak.com"
    #endif

    private var callbackUrl: URL?
    private let displayURL = "transak.com"

    private func buildURLForToken(_ token: String, network: String, address: String) -> URL? {
        var components = URLComponents(string: Self.baseUrlString)

        let queryItems = [
            URLQueryItem(name: "apiKey", value: Self.pubToken),
            URLQueryItem(name: "network", value: network),
            URLQueryItem(name: "cryptoCurrencyCode", value: token),
            URLQueryItem(name: "walletAddress", value: address),
            URLQueryItem(name: "disableWalletAddressForm", value: "true")
        ]

        components?.queryItems = queryItems

        return components?.url
    }
}

// MARK: RampProviderProtocol

extension TransakProvider: RampProviderProtocol {
    func with(callbackUrl: URL) -> Self {
        self.callbackUrl = callbackUrl
        return self
    }

    func buildOffRampActions(
        for chainAsset: ChainAsset,
        accountId: AccountId
    ) -> [RampAction] {
        guard
            let transak = chainAsset.asset.buyProviders?.transak,
            let address = try? accountId.toAddress(using: chainAsset.chain.chainFormat) else {
            return []
        }

        let token = chainAsset.asset.symbol
        let network = transak.network?.stringValue ?? chainAsset.chain.name.lowercased()

        guard let url = buildURLForToken(token, network: network, address: address) else {
            return []
        }

        var paymentMethods = defaultPaymentMethods
        paymentMethods.append(.others("+12"))

        let action = RampAction(
            logo: R.image.transakLogo()!,
            descriptionText: LocalizableResource { locale in
                R.string.localizable.transakBuyActionDescription(preferredLanguages: locale.rLanguages)
            },
            fiatPaymentMethods: paymentMethods,
            url: url
        )

        return [action]
    }

    func buildOnRampActions(
        for chainAsset: ChainAsset,
        accountId: AccountId
    ) -> [RampAction] {
        guard
            let transak = chainAsset.asset.buyProviders?.transak,
            let address = try? accountId.toAddress(using: chainAsset.chain.chainFormat) else {
            return []
        }

        let token = chainAsset.asset.symbol
        let network = transak.network?.stringValue ?? chainAsset.chain.name.lowercased()

        guard let url = buildURLForToken(token, network: network, address: address) else {
            return []
        }

        var paymentMethods = defaultPaymentMethods
        paymentMethods.append(.others("+12"))

        let action = RampAction(
            logo: R.image.transakLogo()!,
            descriptionText: LocalizableResource { locale in
                R.string.localizable.transakBuyActionDescription(preferredLanguages: locale.rLanguages)
            },
            fiatPaymentMethods: paymentMethods,
            url: url
        )

        return [action]
    }
}
