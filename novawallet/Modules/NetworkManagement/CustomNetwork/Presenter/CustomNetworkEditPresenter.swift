import Foundation
import Foundation_iOS

final class CustomNetworkEditPresenter: CustomNetworkBasePresenter {
    let interactor: CustomNetworkEditInteractorInputProtocol

    init(
        chainType: CustomNetworkType,
        interactor: CustomNetworkEditInteractorInputProtocol,
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

        let request = CustomNetwork.EditRequest(
            url: partialURL,
            name: partialName,
            currencySymbol: partialCurrencySymbol,
            chainId: partialChainId,
            blockExplorerURL: partialBlockExplorerURL,
            coingeckoURL: partialCoingeckoURL
        )

        interactor.editNetwork(with: request)
    }

    override func completeButtonTitle() -> String {
        R.string.localizable.commonSave(
            preferredLanguages: selectedLocale.rLanguages
        )
    }

    override func provideURLViewModel() {
        let inputViewModel = InputViewModel.createNotEmptyInputViewModel(
            for: partialURL ?? "",
            enabled: false,
            placeholder: Constants.chainUrlPlaceholder
        )
        view?.didReceiveUrl(viewModel: inputViewModel)
    }
}
