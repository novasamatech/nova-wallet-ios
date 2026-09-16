import Foundation
import Foundation_iOS

protocol FiatPaymentPethodsProviding {
    var defaultFiatPaymentMethods: [FiatPaymentMethods] { get }
}

extension FiatPaymentPethodsProviding {
    var defaultFiatPaymentMethods: [FiatPaymentMethods] {
        [
            .visa,
            .mastercard,
            .applePay,
            .sepa
        ]
    }
}

final class TransakProvider: BaseURLStringProviding,
    RampHookFactoriesProviding,
    FiatPaymentPethodsProviding {
    #if F_RELEASE
        static let baseUrlString = "https://nova-transak.novasama-tech.org"
    #else
        static let baseUrlString = "https://nova-transak-dev.novasama-tech.org"
    #endif

    private var callbackUrl: URL?
    private let displayURL = "transak.com"

    let offRampHookFactory: OffRampHookFactoryProtocol
    let onRampHookFactory: OnRampHookFactoryProtocol
    let bundle: Bundle

    var baseUrlString: String {
        Self.baseUrlString
    }

    init(
        offRampHookFactory: OffRampHookFactoryProtocol = TransakOffRampHookFactory(),
        onRampHookFactory: OnRampHookFactoryProtocol = TransakOnRampHookFactory(),
        bundle: Bundle = .main
    ) {
        self.offRampHookFactory = offRampHookFactory
        self.onRampHookFactory = onRampHookFactory
        self.bundle = bundle
    }
}

// MARK: Private

private extension TransakProvider {
    func createFiatPaymentMethods() -> [FiatPaymentMethods] {
        var fiatPaymentsMethods = defaultFiatPaymentMethods
        fiatPaymentsMethods.append(.others(count: 12))

        return fiatPaymentsMethods
    }

    func buildOffRampActions(
        for chainAsset: ChainAsset,
        accountId: AccountId
    ) -> [RampAction] {
        guard
            let transak = chainAsset.asset.sellProviders?.transak,
            let address = try? accountId.toAddress(using: chainAsset.chain.chainFormat),
            let referrerDomain = bundle.bundleIdentifier
        else {
            return []
        }

        let token = chainAsset.asset.symbol
        let network = transak.network?.stringValue ?? chainAsset.chain.name.lowercased()

        let urlFactory = TransakRampURLFactory(
            actionType: .offRamp,
            baseURL: Self.baseUrlString,
            address: address,
            token: token,
            referrerDomain: referrerDomain,
            network: network
        )

        let action = RampAction(
            providerId: "transak",
            type: .offRamp,
            logo: R.image.transakLogo()!,
            descriptionText: LocalizableResource { locale in
                R.string(preferredLanguages: locale.rLanguages).localizable.transakSellActionDescription()
            },
            urlFactory: urlFactory,
            displayURLString: displayURL,
            paymentMethods: createFiatPaymentMethods()
        )

        return [action]
    }

    func buildOnRampActions(
        for chainAsset: ChainAsset,
        accountId: AccountId
    ) -> [RampAction] {
        guard
            let transak = chainAsset.asset.buyProviders?.transak,
            let address = try? accountId.toAddress(using: chainAsset.chain.chainFormat),
            let referrerDomain = bundle.bundleIdentifier
        else {
            return []
        }

        let token = chainAsset.asset.symbol
        let network = transak.network?.stringValue ?? chainAsset.chain.name.lowercased()

        let urlFactory = TransakRampURLFactory(
            actionType: .onRamp,
            baseURL: Self.baseUrlString,
            address: address,
            token: token,
            referrerDomain: referrerDomain,
            network: network
        )

        let action = RampAction(
            providerId: "transak",
            type: .onRamp,
            logo: R.image.transakLogo()!,
            descriptionText: LocalizableResource { locale in
                R.string(preferredLanguages: locale.rLanguages).localizable.transakBuyActionDescription()
            },
            urlFactory: urlFactory,
            displayURLString: displayURL,
            paymentMethods: createFiatPaymentMethods()
        )

        return [action]
    }
}

// MARK: RampProviderProtocol

extension TransakProvider: RampProviderProtocol {
    func with(callbackUrl: URL) -> Self {
        self.callbackUrl = callbackUrl
        return self
    }

    func buildRampActions(
        for chainAsset: ChainAsset,
        accountId: AccountId
    ) -> [RampAction] {
        buildOnRampActions(for: chainAsset, accountId: accountId)
            + buildOffRampActions(for: chainAsset, accountId: accountId)
    }
}
