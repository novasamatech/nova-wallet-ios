import Foundation
import Keystore_iOS

protocol SwapLastPairStoring: AnyObject {
    var lastPair: SwapAssetPairId? { get }

    func save(payChainAsset: ChainAsset, receiveChainAsset: ChainAsset)
}

final class SwapLastPairStore {
    let settingsManager: SettingsManagerProtocol

    init(settingsManager: SettingsManagerProtocol) {
        self.settingsManager = settingsManager
    }
}

extension SwapLastPairStore: SwapLastPairStoring {
    var lastPair: SwapAssetPairId? {
        settingsManager.value(of: SwapAssetPairId.self, for: SettingsKey.swapLastPair.rawValue)
    }

    func save(payChainAsset: ChainAsset, receiveChainAsset: ChainAsset) {
        let pair = SwapAssetPairId(
            pay: payChainAsset.chainAssetId,
            receive: receiveChainAsset.chainAssetId
        )

        settingsManager.set(value: pair, for: SettingsKey.swapLastPair.rawValue)
    }
}
