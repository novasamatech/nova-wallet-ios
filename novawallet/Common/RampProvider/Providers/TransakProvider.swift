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
        static let pubToken = "861a131b-1721-4e99-8ec3-7349840c888f"
        static let baseUrlString = "https://global.transak.com"
    #else
        static let pubToken = "ed6a6887-57fd-493a-8075-4718b463913b"
        static let baseUrlString = "https://staging-global.transak.com"
    #endif

    private var callbackUrl: URL?
    private let displayURL = "transak.com"

    let offRampHookFactory: OffRampHookFactoryProtocol
    let onRampHookFactory: OnRampHookFactoryProtocol

    var baseUrlString: String {
        Self.baseUrlString
    }

    init(
        offRampHookFactory: OffRampHookFactoryProtocol = TransakOffRampHookFactory(),
        onRampHookFactory: OnRampHookFactoryProtocol = TransakOnRampHookFactory()
    ) {
        self.offRampHookFactory = offRampHookFactory
        self.onRampHookFactory = onRampHookFactory
    }
}

// MARK: Private

private extension TransakProvider {
    func createFiatPaymentMethods() -> [FiatPaymentMethods] {
        var fiatPaymentsMethods = defaultFiatPaymentMethods
        fiatPaymentsMethods.append(.others(count: 12))

        return fiatPaymentsMethods
    }

    func buildURLForToken(
        _ token: String,
        network: String,
        address: String,
        type: RampActionType
    ) -> URL? {
        var components = URLComponents(string: Self.baseUrlString)

        var queryItems = [
            URLQueryItem(name: "apiKey", value: Self.pubToken),
            URLQueryItem(name: "network", value: network),
            URLQueryItem(name: "cryptoCurrencyCode", value: token)
        ]

        let productsAvailed = switch type {
        case .offRamp: "SELL"
        case .onRamp: "BUY"
        }

        if type == .onRamp {
            queryItems.append(URLQueryItem(name: "walletAddress", value: address))
            queryItems.append(URLQueryItem(name: "disableWalletAddressForm", value: "true"))
        }

        queryItems.append(URLQueryItem(name: "productsAvailed", value: productsAvailed))

        components?.queryItems = queryItems

        return components?.url
    }

    func buildOffRampActions(
        for chainAsset: ChainAsset,
        accountId: AccountId
    ) -> [RampAction] {
        guard
            let transak = chainAsset.asset.sellProviders?.transak,
            let address = try? accountId.toAddress(using: chainAsset.chain.chainFormat) else {
            return []
        }

        let token = chainAsset.asset.symbol
        let network = transak.network?.stringValue ?? chainAsset.chain.name.lowercased()

        let urlFactory = TransakRampURLFactory(
            actionType: .offRamp,
            pubToken: Self.pubToken,
            baseURL: Self.baseUrlString,
            address: address,
            token: token,
            network: network
        )

        let action = RampAction(
            type: .offRamp,
            logo: R.image.transakLogo()!,
            descriptionText: LocalizableResource { locale in
                R.string.localizable.transakSellActionDescription(preferredLanguages: locale.rLanguages)
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
            let address = try? accountId.toAddress(using: chainAsset.chain.chainFormat) else {
            return []
        }

        let token = chainAsset.asset.symbol
        let network = transak.network?.stringValue ?? chainAsset.chain.name.lowercased()

        let urlFactory = TransakRampURLFactory(
            actionType: .onRamp,
            pubToken: Self.pubToken,
            baseURL: Self.baseUrlString,
            address: address,
            token: token,
            network: network
        )

        let action = RampAction(
            type: .onRamp,
            logo: R.image.transakLogo()!,
            descriptionText: LocalizableResource { locale in
                R.string.localizable.transakBuyActionDescription(preferredLanguages: locale.rLanguages)
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
