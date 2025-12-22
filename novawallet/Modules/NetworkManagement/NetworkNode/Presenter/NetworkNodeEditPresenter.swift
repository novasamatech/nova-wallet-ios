import Foundation
import Foundation_iOS

final class NetworkNodeEditPresenter: NetworkNodeBasePresenter {
    let interactor: NetworkNodeEditInteractorInputProtocol

    init(
        interactor: any NetworkNodeEditInteractorInputProtocol,
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

        interactor.editNode(
            with: partialURL,
            name: partialName
        )
    }

    override func completeButtonTitle() -> String {
        R.string(preferredLanguages: selectedLocale.rLanguages).localizable.commonSave()
    }

    override func provideTitle() {
        let title = R.string(preferredLanguages: selectedLocale.rLanguages).localizable.networkNodeEditTitle()
        view?.didReceiveTitle(text: title)
    }
}

// MARK: NetworkNodeEditInteractorOutputProtocol

extension NetworkNodeEditPresenter: NetworkNodeEditInteractorOutputProtocol {
    func didEditNode() {
        wireframe.showNetworkDetails(from: view)
        provideButtonViewModel(loading: false)
    }

    func didReceive(node: ChainNodeModel) {
        partialURL = node.url
        partialName = node.name

        provideNameViewModel()
        provideURLViewModel(for: nil)
        provideButtonViewModel(loading: false)
    }
}
