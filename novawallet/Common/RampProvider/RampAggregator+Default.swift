import Foundation

extension RampAggregator {
    static func defaultAggregator() -> RampAggregator {
        let config: ApplicationConfigProtocol = ApplicationConfig.shared

        let rampProviders: [RampProviderProtocol] = [
            MercuryoProvider(),
            TransakProvider(),
            BanxaProvider()
        ]

        return RampAggregator(providers: rampProviders)
            .with(appName: config.purchaseAppName)
            .with(logoUrl: config.logoURL)
            .with(colorCode: R.color.colorIconAccent()!.hexRGB)
            .with(callbackUrl: config.purchaseRedirect)
    }
}
