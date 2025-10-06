import Foundation
import Keystore_iOS

final class AHMInfoInteractor {
    weak var presenter: AHMInfoInteractorOutputProtocol?

    private let info: AHMRemoteData
    private let chainRegistry: ChainRegistryProtocol
    private let settingsManager: SettingsManagerProtocol

    init(
        info: AHMRemoteData,
        chainRegistry: ChainRegistryProtocol,
        settingsManager: SettingsManagerProtocol
    ) {
        self.info = info
        self.chainRegistry = chainRegistry
        self.settingsManager = settingsManager
    }
}

// MARK: - AHMInfoInteractorInputProtocol

extension AHMInfoInteractor: AHMInfoInteractorInputProtocol {
    func setup() {
        if let sourceChain = chainRegistry.getChain(for: info.sourceData.chainId) {
            presenter?.didReceive(sourceChain: sourceChain)
        }

        if let destinationChain = chainRegistry.getChain(for: info.destinationData.chainId) {
            presenter?.didReceive(destinationChain: destinationChain)
        }
    }

    func setShown() {
        settingsManager.ahmInfoShownChains.add(info.sourceData.chainId)
    }
}
