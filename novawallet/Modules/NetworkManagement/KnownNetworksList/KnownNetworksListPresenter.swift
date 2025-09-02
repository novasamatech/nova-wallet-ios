import Foundation
import Foundation_iOS

final class KnownNetworksListPresenter {
    weak var view: KnownNetworksListViewProtocol?
    let wireframe: KnownNetworksListWireframeProtocol
    let interactor: KnownNetworksListInteractorInputProtocol

    private let viewModelFactory: KnownNetworksListviewModelFactory

    private var chains: [LightChainModel] = []

    init(
        interactor: KnownNetworksListInteractorInputProtocol,
        wireframe: KnownNetworksListWireframeProtocol,
        viewModelFactory: KnownNetworksListviewModelFactory,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory
        self.localizationManager = localizationManager
    }
}

// MARK: KnownNetworksListPresenterProtocol

extension KnownNetworksListPresenter: KnownNetworksListPresenterProtocol {
    func becameActive() {
        view?.didStartLoading()
        provideViewModels()

        interactor.provideChains()
    }

    func selectChain(at index: Int) {
        view?.didStartLoading()
        let selectedLightChain = chains[index]

        interactor.provideChain(with: selectedLightChain.chainId)
    }

    func search(by query: String) {
        interactor.searchChain(by: query)
    }

    func addNetworkManually() {
        wireframe.showAddNetwork(
            from: view,
            with: nil
        )
    }
}

// MARK: KnownNetworksListInteractorOutputProtocol

extension KnownNetworksListPresenter: KnownNetworksListInteractorOutputProtocol {
    func provideViewModels() {
        let viewModel = viewModelFactory.createViewModel(
            with: chains,
            selectedLocale
        )

        view?.update(with: viewModel)
    }

    func didReceive(_ chains: [LightChainModel]) {
        view?.didStopLoading()

        self.chains = chains
        provideViewModels()
    }

    func didReceive(_ chain: ChainModel) {
        view?.didStopLoading()

        wireframe.showAddNetwork(
            from: view,
            with: chain
        )
    }

    func didReceive(_ error: any Error) {
        wireframe.present(
            error: error,
            from: view,
            locale: selectedLocale
        )
    }
}

// MARK: Localizable

extension KnownNetworksListPresenter: Localizable {
    func applyLocalization() {
        guard let view, view.isSetup else { return }

        provideViewModels()
    }
}
