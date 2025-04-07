import Foundation

extension RampAggregator {
    static func defaultAggregator() -> RampAggregator {
        let config: ApplicationConfigProtocol = ApplicationConfig.shared

        let rampProviders: [RampProviderProtocol] = [
            MercuryoProvider(offRampHookFactory: MercuryoOffRampHookFactory()),
            TransakProvider(offRampHookFactory: TransakOffRampHookFactory()),
            BanxaProvider()
        ]

        return RampAggregator(providers: rampProviders)
            .with(appName: config.purchaseAppName)
            .with(logoUrl: config.logoURL)
            .with(colorCode: R.color.colorIconAccent()!.hexRGB)
            .with(callbackUrl: config.purchaseRedirect)
    }
}
