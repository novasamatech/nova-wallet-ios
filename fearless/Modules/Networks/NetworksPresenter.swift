import Foundation
import RobinHood
import SoraFoundation
import IrohaCrypto

final class NetworksPresenter {
    weak var view: NetworksViewProtocol?
    let wireframe: NetworksWireframeProtocol
    let interactor: NetworksInteractorInputProtocol
    let viewModelFactory: NetworksViewModelFactoryProtocol
    let logger: LoggerProtocol?

    private var chains: [ChainModel]?
    private var chainSettings = Set<ChainSettingsModel>()

    init(
        interactor: NetworksInteractorInputProtocol,
        wireframe: NetworksWireframeProtocol,
        viewModelFactory: NetworksViewModelFactoryProtocol,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol? = nil
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory
        self.logger = logger
        self.localizationManager = localizationManager
    }

    private func updateView() {
        guard let chains = chains else { return }
        let viewModel = viewModelFactory.createViewModel(
            chains: chains,
            chainSettings: chainSettings,
            locale: selectedLocale
        )
        view?.reload(viewModel: viewModel)
    }
}

extension NetworksPresenter: Localizable {
    func applyLocalization() {
        if let view = view, view.isSetup {
            updateView()
        }
    }
}

extension NetworksPresenter: NetworksPresenterProtocol {
    func setup() {
        interactor.setup()
    }
}

extension NetworksPresenter: NetworksInteractorOutputProtocol {
    func didReceive(chainsResult: Result<[ChainModel]?, Error>) {
        switch chainsResult {
        case let .success(chains):
            self.chains = chains
            updateView()
        case let .failure(error):
            logger?.error(error.localizedDescription)
        }
    }

    func didReceive(chainSettingsResult: Result<ChainSettingsModel?, Error>) {
        switch chainSettingsResult {
        case let .success(chainSettingsModel):
            guard let chainSettingsModel = chainSettingsModel else { return }
            chainSettings.insert(chainSettingsModel)
            updateView()
        case let .failure(error):
            logger?.error(error.localizedDescription)
        }
    }
}
