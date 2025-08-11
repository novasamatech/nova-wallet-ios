import Foundation
import CryptoKit
import SubstrateSdk
import Foundation_iOS

final class BanxaProvider: BaseURLStringProviding,
    FiatPaymentPethodsProviding {
    private var callbackUrl: URL?
    private var colorCode: String?
    private let displayURL = "banxa.com"

    var baseUrlString: String {
        #if F_RELEASE
            "https://novawallet.banxa.com"
        #else
            "https://novawallet.banxa-sandbox.com"
        #endif
    }
}

// MARK: Private

private extension BanxaProvider {
    func createFiatPaymentMethods() -> [FiatPaymentMethods] {
        var fiatPaymentsMethods = defaultFiatPaymentMethods
        fiatPaymentsMethods.append(.others(count: 5))

        return fiatPaymentsMethods
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

        let urlFactory = BanxaRampURLFactory(
            baseURL: baseUrlString,
            address: address,
            token: token,
            network: network
        )

        let action = RampAction(
            type: .onRamp,
            logo: R.image.banxaLogo()!,
            descriptionText: LocalizableResource { locale in
                R.string.localizable.banxaBuyActionDescription(preferredLanguages: locale.rLanguages)
            },
            urlFactory: urlFactory,
            displayURLString: displayURL,
            paymentMethods: createFiatPaymentMethods()
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
        for _: RampHookDelegate
    ) -> [RampHook] {
        []
    }
}
