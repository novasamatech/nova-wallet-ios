import Foundation
import SoraFoundation

final class CustomNetworkAddPresenter: CustomNetworkBasePresenter {
    
    let interactor: CustomNetworkAddInteractorInputProtocol
    
    init(
        chainType: ChainType,
        interactor: CustomNetworkAddInteractorInputProtocol,
        wireframe: CustomNetworkWireframeProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.interactor = interactor
        
        super.init(
            chainType: chainType,
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
    
    override func provideTitle() {
        let title = R.string.localizable.networkAddTitle(
            preferredLanguages: selectedLocale.rLanguages
        )
        view?.didReceiveTitle(text: title)
    }
}

// MARK: CustomNetworkAddInteractorOutputProtocol

extension CustomNetworkAddPresenter: CustomNetworkAddInteractorOutputProtocol {
    func didAddChain() {
        // TODO: Route via wireframe
        provideButtonViewModel(loading: true)
    }
}
