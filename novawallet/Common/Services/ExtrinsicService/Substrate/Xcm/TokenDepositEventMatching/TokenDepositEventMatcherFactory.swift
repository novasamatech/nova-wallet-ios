import Foundation

protocol TokenDepositEventMatcherFactoryProtocol {
    func createMatcher(for chainAsset: ChainAsset) -> TokenDepositEventMatching?
}

final class TokenDepositEventMatcherFactory: TokenDepositEventMatcherFactoryProtocol {
    let logger: LoggerProtocol

    init(logger: LoggerProtocol) {
        self.logger = logger
    }

    func createMatcher(for chainAsset: ChainAsset) -> TokenDepositEventMatching? {
        try? CustomAssetMapper(
            type: chainAsset.asset.type,
            typeExtras: chainAsset.asset.typeExtras
        ).mapAssetWithExtras(
            nativeHandler: {
                TokenFirstOfDepositEventMatcher(
                    matchers: [
                        NativeTokenMintedEventMatcher(logger: logger),
                        NativeTokenDepositedEventMatcher(logger: logger)
                    ]
                )
            },
            statemineHandler: { extras in
                PalletAssetsTokenDepositEventMatcher(extras: extras, logger: logger)
            },
            ormlHandler: { extras in
                TokensPalletDepositEventMatcher(extras: extras, logger: logger)
            }, evmHandler: { _ in
                nil
            },
            evmNativeHandler: {
                nil
            },
            equilibriumHandler: { _ in
                nil
            }
        )
    }
}
