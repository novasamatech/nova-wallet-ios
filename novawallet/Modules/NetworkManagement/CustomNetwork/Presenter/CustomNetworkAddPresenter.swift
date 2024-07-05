import Foundation
import SoraFoundation

final class CustomNetworkAddPresenter: CustomNetworkBasePresenter {
    
    let interactor: CustomNetworkAddInteractorInputProtocol
    
    init(
        chainType: ChainType,
        knownChain: ChainModel?,
        interactor: CustomNetworkAddInteractorInputProtocol,
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
        
        interactor.addNetwork(
            networkType: chainType,
            url: partialURL,
            name: partialName,
            currencySymbol: partialCurrencySymbol,
            chainId: partialChainId,
            blockExplorerURL: partialBlockExplorerURL,
            coingeckoURL: partialCoingeckoURL
        )
    }
    
    override func completeButtonTitle() -> String {
        R.string.localizable.networksListAddNetworkButtonTitle(
            preferredLanguages: selectedLocale.rLanguages
        )
    }
}
