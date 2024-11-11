import Foundation

protocol TokenDepositEventMatcherFactoryProtocol {
    func createMatcher(for chainAsset: ChainAsset) -> TokenDepositEventMatching?
}

final class TokenDepositEventMatcherFactory: TokenDepositEventMatcherFactoryProtocol {
    func createMatcher(for chainAsset: ChainAsset) -> TokenDepositEventMatching? {
        try? CustomAssetMapper(
            type: chainAsset.asset.type,
            typeExtras: chainAsset.asset.typeExtras
        ).mapAssetWithExtras(
            nativeHandler: {
                NativeTokenDepositEventMatcher()
            },
            statemineHandler: { extras in
                PalletAssetsTokenDepositEventMatcher(extras: extras)
            },
            ormlHandler: { extras in
                TokensPalletDepositEventMatcher(extras: extras)
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
