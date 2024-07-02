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
    
    override func completeSetup() {
        super.completeSetup()
        
        interactor.setup()
    }
}

// MARK: CustomNetworkEditInteractorOutputProtocol

extension CustomNetworkEditPresenter: CustomNetworkEditInteractorOutputProtocol {
    
    func didReceive(chain: ChainModel) {
        let mainAsset = chain.assets.first { $0.assetId == 0 }
        
        partialURL = chain.nodes.first?.url
        partialName = chain.name
        partialCurrencySymbol = mainAsset?.name
        partialChainId = "\(chain.addressPrefix)"
        partialBlockExplorerURL = blockExplorerUrl(from: chain.explorers?.first?.extrinsic)
        partialCoingeckoURL = if let priceId = mainAsset?.priceId {
            [Constants.coingeckoUrl, priceId].joined(with: .slash)
        } else {
            nil
        }
    }
    
    func didEditChain() {
        provideButtonViewModel(loading: false)
        
        wireframe.showPrevious(from: view)
    }
}

// MARK: Private

private extension CustomNetworkEditPresenter {
    func blockExplorerUrl(from template: String?) -> String? {
        guard let template else { return nil }
        
        var urlComponents = URLComponents(
            url: URL(string: template)!,
            resolvingAgainstBaseURL: false
        )
        urlComponents?.path = ""
        urlComponents?.queryItems = []
        
        let trimmedUrlString = urlComponents?
            .url?
            .absoluteString
            .trimmingCharacters(in: CharacterSet(charactersIn:"?"))
        
        return trimmedUrlString ?? template
    }
}

// MARK: Constants

private extension CustomNetworkEditPresenter {
    enum Constants {
        static let coingeckoUrl = "https://coingecko.com/coins"
    }
}
