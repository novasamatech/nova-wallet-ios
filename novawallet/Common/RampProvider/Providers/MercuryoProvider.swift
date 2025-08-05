import Foundation
import CryptoKit
import SubstrateSdk
import Foundation_iOS

final class MercuryoProvider: BaseURLStringProviding,
    RampHookFactoriesProviding,
    FiatPaymentPethodsProviding {
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

    private let ipAddressProvider: IPAddressProviderProtocol

    private var callbackUrl: URL?
    private let displayURL = "mercuryo.io"

    #if F_RELEASE
        let configuration: Configuration = .production
    #else
        let configuration: Configuration = .debug
    #endif

    let offRampHookFactory: OffRampHookFactoryProtocol
    let onRampHookFactory: OnRampHookFactoryProtocol
    let merchantIdFactory: MerchantTransactionIdFactory

    var baseUrlString: String {
        configuration.baseUrl
    }

    init(
        offRampHookFactory: OffRampHookFactoryProtocol = MercuryoOffRampHookFactory(),
        onRampHookFactory: OnRampHookFactoryProtocol = MercuryoOnRampHookFactory(),
        merchantIdFactory: MerchantTransactionIdFactory = UUIDMerchantTransactionIdFactory(),
        ipAddressProvider: IPAddressProviderProtocol = IPAddressProvider()
    ) {
        self.offRampHookFactory = offRampHookFactory
        self.onRampHookFactory = onRampHookFactory
        self.merchantIdFactory = merchantIdFactory
        self.ipAddressProvider = ipAddressProvider
    }
}

// MARK: Private

private extension MercuryoProvider {
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
            chainAsset.asset.buyProviders?.mercuryo != nil,
            let address = try? accountId.toAddress(using: chainAsset.chain.chainFormat) else {
            return []
        }

        guard let callbackUrl = self.callbackUrl else {
            return []
        }

        let urlFactory = MercuryoRampURLFactory(
            actionType: .onRamp,
            secret: configuration.secret,
            baseURL: configuration.baseUrl,
            address: address,
            token: chainAsset.asset.symbol,
            widgetId: configuration.widgetId,
            callBackURL: callbackUrl,
            ipAddressProvider: ipAddressProvider,
            merchantIdFactory: merchantIdFactory
        )

        let action = RampAction(
            type: .onRamp,
            logo: R.image.mercuryoLogo()!,
            descriptionText: LocalizableResource { locale in
                R.string.localizable.mercuryoBuyActionDescription(preferredLanguages: locale.rLanguages)
            },
            urlFactory: urlFactory,
            displayURLString: displayURL,
            paymentMethods: createFiatPaymentMethods()
        )

        return [action]
    }

    func buildOffRampActions(
        for chainAsset: ChainAsset,
        accountId: AccountId
    ) -> [RampAction] {
        guard
            chainAsset.asset.sellProviders?.mercuryo != nil,
            let address = try? accountId.toAddress(using: chainAsset.chain.chainFormat) else {
            return []
        }

        let urlFactory = MercuryoRampURLFactory(
            actionType: .offRamp,
            secret: configuration.secret,
            baseURL: configuration.baseUrl,
            address: address,
            token: chainAsset.asset.symbol,
            widgetId: configuration.widgetId,
            ipAddressProvider: ipAddressProvider,
            merchantIdFactory: merchantIdFactory
        )

        let action = RampAction(
            type: .offRamp,
            logo: R.image.mercuryoLogo()!,
            descriptionText: LocalizableResource { locale in
                R.string.localizable.mercuryoSellActionDescription(preferredLanguages: locale.rLanguages)
            },
            urlFactory: urlFactory,
            displayURLString: displayURL,
            paymentMethods: createFiatPaymentMethods()
        )

        return [action]
    }
}

// MARK: RampProviderProtocol

extension MercuryoProvider: RampProviderProtocol {
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
