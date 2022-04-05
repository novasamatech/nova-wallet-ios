import Foundation

extension PurchaseAggregator {
    static func defaultAggregator() -> PurchaseAggregator {
        let config: ApplicationConfigProtocol = ApplicationConfig.shared

        // TODO: Waiting for KYB to get secrets
        /* let moonpaySecretKeyData = Data(MoonPayKeys.secretKey.utf8)
         let moonpayProvider = MoonpayProviderFactory().createProvider(
             with: moonpaySecretKeyData,
             apiKey: config.moonPayApiKey
         )*/

        let purchaseProviders: [PurchaseProviderProtocol] = [
            RampProvider(),
            TransakProvider()
        ]
        return PurchaseAggregator(providers: purchaseProviders)
            .with(appName: config.purchaseAppName)
            .with(logoUrl: config.logoURL)
            .with(colorCode: R.color.colorAccent()!.hexRGB)
            .with(callbackUrl: config.purchaseRedirect)
    }
}
