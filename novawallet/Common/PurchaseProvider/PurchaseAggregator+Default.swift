import Foundation

extension PurchaseAggregator {
    static func defaultAggregator() -> PurchaseAggregator {
        let config: ApplicationConfigProtocol = ApplicationConfig.shared

        let purchaseProviders: [PurchaseProviderProtocol] = [
            TransakProvider(),
            BanxaProvider(),
            MercuryoProvider()
        ]
        return PurchaseAggregator(providers: purchaseProviders)
            .with(appName: config.purchaseAppName)
            .with(logoUrl: config.logoURL)
            .with(colorCode: R.color.colorIconAccent()!.hexRGB)
            .with(callbackUrl: config.purchaseRedirect)
    }
}
