import Foundation
import Foundation_iOS

final class NetworkNodeAddPresenter: NetworkNodeBasePresenter {
    let interactor: NetworkNodeAddInteractorInputProtocol

    init(
        interactor: any NetworkNodeAddInteractorInputProtocol,
        wireframe: any NetworkNodeWireframeProtocol,
        networkViewModelFactory: any NetworkViewModelFactoryProtocol,
        localizationManager: any LocalizationManagerProtocol
    ) {
        self.interactor = interactor

        super.init(
            interactor: interactor,
            wireframe: wireframe,
            networkViewModelFactory: networkViewModelFactory,
            localizationManager: localizationManager
        )
    }

    override func actionConfirm() {
        guard let partialURL, let partialName else { return }

        interactor.addNode(
            with: partialURL,
            name: partialName
        )
    }

    override func completeButtonTitle() -> String {
        R.string.localizable.networkNodeAddButtonAdd(
            preferredLanguages: selectedLocale.rLanguages
        )
    }

    override func provideTitle() {
        let title = R.string.localizable.networkNodeAddTitle(
            preferredLanguages: selectedLocale.rLanguages
        )
        view?.didReceiveTitle(text: title)
    }
}

// MARK: NetworkNodeAddInteractorOutputProtocol

extension NetworkNodeAddPresenter: NetworkNodeAddInteractorOutputProtocol {
    func didAddNode() {
        wireframe.showNetworkDetails(from: view)
        provideButtonViewModel(loading: false)
    }
}
