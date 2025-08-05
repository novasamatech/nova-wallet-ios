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

    #if F_RELEASE
        let configuration: Configuration = .production
    #else
        let configuration: Configuration = .debug
    #endif

    private var callbackUrl: URL?
    private let displayURL = "mercuryo.io"

    let offRampHookFactory: OffRampHookFactoryProtocol
    let onRampHookFactory: OnRampHookFactoryProtocol

    var baseUrlString: String {
        configuration.baseUrl
    }

    init(
        offRampHookFactory: OffRampHookFactoryProtocol = MercuryoOffRampHookFactory(),
        onRampHookFactory: OnRampHookFactoryProtocol = MercuryoOnRampHookFactory()
    ) {
        self.offRampHookFactory = offRampHookFactory
        self.onRampHookFactory = onRampHookFactory
    }
}

// MARK: Private

private extension MercuryoProvider {
    func createFiatPaymentMethods() -> [FiatPaymentMethods] {
        var fiatPaymentsMethods = defaultFiatPaymentMethods
        fiatPaymentsMethods.append(.others(count: 5))

        return fiatPaymentsMethods
    }

    func buildURL(
        address: AccountAddress,
        token: String,
        actionType: RampActionType,
        callbackUrl: URL?
    ) -> URL? {
        guard let signatureData = [address, configuration.secret].joined().data(using: .utf8) else {
            return nil
        }
        let signature = Data(SHA512.hash(data: signatureData).makeIterator())
        var components = URLComponents(string: configuration.baseUrl)

        let type = switch actionType {
        case .onRamp: "buy"
        case .offRamp: "sell"
        }

        var queryItems = [
            URLQueryItem(name: "currency", value: token),
            URLQueryItem(name: "type", value: type),
            URLQueryItem(name: "address", value: address),
            URLQueryItem(name: "widget_id", value: configuration.widgetId),
            URLQueryItem(name: "signature", value: signature.toHex())
        ]

        if let callbackUrl {
            queryItems.append(URLQueryItem(name: "return_url", value: callbackUrl.absoluteString))
        }

        if actionType == .offRamp {
            queryItems.append(URLQueryItem(name: "hide_refund_address", value: "true"))
            queryItems.append(URLQueryItem(name: "refund_address", value: address))
        }

        components?.queryItems = queryItems

        return components?.url
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
            callBackURL: callbackUrl
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
            actionType: .onRamp,
            secret: configuration.secret,
            baseURL: configuration.baseUrl,
            address: address,
            token: chainAsset.asset.symbol,
            widgetId: configuration.widgetId
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
