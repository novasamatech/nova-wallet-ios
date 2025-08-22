import Foundation

enum TokenDepositEventMatcherFactory {
    static func createMatcher(
        for chainAsset: ChainAsset,
        logger: LoggerProtocol
    ) -> [TokenDepositEventMatching]? {
        try? CustomAssetMapper(
            type: chainAsset.asset.type,
            typeExtras: chainAsset.asset.typeExtras
        ).mapAssetWithExtras(
            .init(
                nativeHandler: {
                    [
                        NativeTokenMintedEventMatcher(logger: logger),
                        NativeTokenDepositedEventMatcher(logger: logger)
                    ]
                },
                statemineHandler: { extras in
                    [
                        PalletAssetsTokenDepositEventMatcher(extras: extras, logger: logger)
                    ]
                },
                ormlHandler: { extras in
                    [
                        TokensPalletDepositEventMatcher(extras: extras, logger: logger)
                    ]
                },
                ormlHydrationEvmHandler: { extras in
                    // TODO: GDOT Check that this actually works
                    [
                        TokensPalletDepositEventMatcher(extras: extras, logger: logger)
                    ]
                },
                evmHandler: { contractAccountId in
                    [
                        MoonbeamEvmMintedEventMatcher(
                            contractAccountId: contractAccountId,
                            logger: logger
                        )
                    ]
                },
                evmNativeHandler: {
                    nil
                },
                equilibriumHandler: { _ in
                    nil
                }
            )
        )
    }
}
