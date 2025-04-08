import Foundation
import CryptoKit
import SubstrateSdk
import Foundation_iOS

final class BanxaProvider {
    #if F_RELEASE
        let host = "https://novawallet.banxa.com"
    #else
        let host = "https://novawallet.banxa-sandbox.com"
    #endif

    private var callbackUrl: URL?
    private var colorCode: String?
    private let displayURL = "banxa.com"
}

// MARK: Private

private extension BanxaProvider {
    func buildURL(
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

    func buildOnRampActions(
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

        let action = RampAction(
            type: .onRamp,
            logo: R.image.banxaLogo()!,
            descriptionText: LocalizableResource { locale in
                R.string.localizable.banxaBuyActionDescription(preferredLanguages: locale.rLanguages)
            },
            url: url,
            displayURLString: displayURL
        )

        return [action]
    }
}

// MARK: RampProviderProtocol

extension BanxaProvider: RampProviderProtocol {
    func with(callbackUrl: URL) -> Self {
        self.callbackUrl = callbackUrl
        return self
    }

    func buildRampActions(
        for chainAsset: ChainAsset,
        accountId: AccountId
    ) -> [RampAction] {
        buildOnRampActions(for: chainAsset, accountId: accountId)
    }

    func buildRampHooks(
        for _: RampAction,
        using _: OffRampHookParams,
        for _: any OffRampHookDelegate & OnRampHookDelegate
    ) -> [RampHook] {
        []
    }
}
