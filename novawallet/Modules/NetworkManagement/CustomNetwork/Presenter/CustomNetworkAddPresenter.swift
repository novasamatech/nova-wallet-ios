import Foundation
import Foundation_iOS

final class CustomNetworkAddPresenter: CustomNetworkBasePresenter {
    let interactor: CustomNetworkAddInteractorInputProtocol

    init(
        chainType: CustomNetworkType,
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

        let request = CustomNetwork.AddRequest(
            networkType: chainType,
            url: partialURL,
            name: partialName,
            currencySymbol: partialCurrencySymbol,
            chainId: partialChainId,
            blockExplorerURL: partialBlockExplorerURL,
            coingeckoURL: partialCoingeckoURL
        )

        interactor.addNetwork(with: request)
    }

    override func completeButtonTitle() -> String {
        R.string(preferredLanguages: selectedLocale.rLanguages
        ).localizable.networksListAddNetworkButtonTitle()
    }

    override func handleUrl(_ url: String) {
        guard
            chainType == .substrate,
            NSPredicate.ws.evaluate(with: url)
        else {
            return
        }

        provideButtonViewModel(loading: true)
        interactor.fetchNetworkProperties(for: url)
    }
}
