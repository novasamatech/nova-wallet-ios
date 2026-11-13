import Foundation
import Keystore_iOS

protocol SwapTokenSelectNetworksStoring: AnyObject {
    var savedNetworks: [ChainModel.Id] { get }

    func save(networks: [ChainModel.Id])
}

final class SwapTokenSelectNetworksStore {
    let settingsManager: SettingsManagerProtocol

    init(settingsManager: SettingsManagerProtocol) {
        self.settingsManager = settingsManager
    }
}

extension SwapTokenSelectNetworksStore: SwapTokenSelectNetworksStoring {
    var savedNetworks: [ChainModel.Id] {
        settingsManager.value(
            of: [ChainModel.Id].self,
            for: SettingsKey.swapTokenSelectNetworks.rawValue
        ) ?? []
    }

    func save(networks: [ChainModel.Id]) {
        settingsManager.set(value: networks, for: SettingsKey.swapTokenSelectNetworks.rawValue)
    }
}
