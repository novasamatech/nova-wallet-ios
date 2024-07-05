import Foundation
import SoraFoundation

final class CustomNetworkEditPresenter: CustomNetworkBasePresenter {
    
    let interactor: CustomNetworkEditInteractorInputProtocol
    
    init(
        chainType: ChainType,
        knownChain: ChainModel?,
        interactor: CustomNetworkEditInteractorInputProtocol,
        wireframe: CustomNetworkWireframeProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.interactor = interactor
        
        super.init(
            chainType: chainType,
            knownChain: knownChain,
            interactor: interactor,
            wireframe: wireframe,
            localizationManager: localizationManager
        )
    }
    
    override func actionConfirm() {
        guard
            let partialURL,
            let partialName,
            let partialCurrencySymbol
        else {
            return
        }
        
        interactor.editNetwork(
            url: partialURL,
            name: partialName,
            currencySymbol: partialCurrencySymbol,
            chainId: partialChainId,
            blockExplorerURL: partialBlockExplorerURL,
            coingeckoURL: partialCoingeckoURL
        )
    }
    
    override func completeButtonTitle() -> String {
        R.string.localizable.commonSave(
            preferredLanguages: selectedLocale.rLanguages
        )
    }
}
