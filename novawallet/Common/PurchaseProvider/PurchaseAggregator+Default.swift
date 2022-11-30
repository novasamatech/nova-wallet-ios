import Foundation

extension PurchaseAggregator {
    static func defaultAggregator() -> PurchaseAggregator {
        let config: ApplicationConfigProtocol = ApplicationConfig.shared

        let purchaseProviders: [PurchaseProviderProtocol] = [
            MercuryoProvider(),
            TransakProvider()
        ]
        return PurchaseAggregator(providers: purchaseProviders)
            .with(appName: config.purchaseAppName)
            .with(logoUrl: config.logoURL)
            .with(colorCode: R.color.colorIconAccent()!.hexRGB)
            .with(callbackUrl: config.purchaseRedirect)
    }
}
