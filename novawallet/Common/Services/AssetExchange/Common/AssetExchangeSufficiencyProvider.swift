import Foundation

protocol AssetExchangeSufficiencyProviding {
    func isSufficient(chainAsset: ChainAsset) -> Bool
}

final class AssetExchangeSufficiencyProvider: AssetExchangeSufficiencyProviding {
    func isSufficient(chainAsset: ChainAsset) -> Bool {
        switch AssetType(rawType: chainAsset.asset.type) {
        case .none, .orml, .equilibrium, .evmAsset, .evmNative:
            return true
        case .statemine:
            return chainAsset.asset.typeExtras?.isSufficient?.boolValue ?? false
        }
    }
}
