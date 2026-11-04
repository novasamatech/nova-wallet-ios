import Foundation

extension SwapModel {
    var noProviderLeftAfterSwap: Bool {
        guard receiveChainAsset.mayBackHydraAaveLoan else {
            let isSelfSufficient = receiveAssetExistense?.isSelfSufficient ?? false
            return !isSelfSufficient && nativeTokenProviderWillBeKilled
        }

        guard let accountInfo, (accountInfo.sufficients ?? 0) == 0 else {
            return false
        }

        let killedProviders = [
            payTokenProviderWillBeKilled && !payChainAsset.mayBackHydraAaveLoan,
            nativeTokenProviderWillBeKilled && !payChainAsset.isUtilityAsset
        ].filter { $0 }.count

        return killedProviders > 0 && killedProviders >= Int(accountInfo.providers ?? 0)
    }
}
