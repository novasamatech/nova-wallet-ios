import Foundation
import SoraFoundation

final class NetworkAddNodePresenter {
    weak var view: NetworkAddNodeViewProtocol?
    let wireframe: NetworkAddNodeWireframeProtocol
    let interactor: NetworkAddNodeInteractorInputProtocol

    private var partialURL: String?
    private var partialName: String?

    init(
        interactor: NetworkAddNodeInteractorInputProtocol,
        wireframe: NetworkAddNodeWireframeProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.localizationManager = localizationManager
    }
}

// MARK: NetworkAddNodePresenterProtocol

extension NetworkAddNodePresenter: NetworkAddNodePresenterProtocol {
    func setup() {
        provideViewModel()
    }

    func handlePartial(url: String) {
        partialURL = url
    }

    func handlePartial(name: String) {
        partialName = name
    }

    func confirmAddNode() {}
}

// MARK: NetworkAddNodeInteractorOutputProtocol

extension NetworkAddNodePresenter: NetworkAddNodeInteractorOutputProtocol {}

// MARK: Private

private extension NetworkAddNodePresenter {
    func provideViewModel() {
        provideURLViewModel()
        provideNameViewModel()
    }

    func provideURLViewModel() {
        let inputViewModel = InputViewModel.createSubstrateNodeURLInputViewModel(
            for: partialURL ?? "",
            placeholder: "wss://rpc.polkadot.io"
        )
        view?.didReceiveUrl(viewModel: inputViewModel)
    }

    func provideNameViewModel() {
        let inputViewModel = InputViewModel.createSubstrateNodeNameInputViewModel(
            for: partialName ?? "",
            placeholder: R.string.localizable.commonName(preferredLanguages: selectedLocale.rLanguages)
        )
        view?.didReceiveName(viewModel: inputViewModel)
    }
}

// MARK: Localizable

extension NetworkAddNodePresenter: Localizable {
    func applyLocalization() {
        guard let view, view.isSetup else { return }

        provideViewModel()
    }
}
