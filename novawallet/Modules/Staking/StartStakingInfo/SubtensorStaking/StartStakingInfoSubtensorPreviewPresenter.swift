import Foundation
import Foundation_iOS

final class StartStakingInfoSubtensorPreviewPresenter {
    weak var view: StartStakingInfoSubtensorViewProtocol?

    let interactor: StartStakingInfoSubtensorPreviewInteractorInputProtocol
    let wireframe: StartStakingInfoSubtensorPreviewWireframeProtocol
    let viewModelFactory: StartStakingInfoSubtensorViewModelFactoryProtocol
    let localizationManager: LocalizationManagerProtocol

    private var previewData: SubtensorStakingPreviewData?

    init(
        interactor: StartStakingInfoSubtensorPreviewInteractorInputProtocol,
        wireframe: StartStakingInfoSubtensorPreviewWireframeProtocol,
        viewModelFactory: StartStakingInfoSubtensorViewModelFactoryProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory
        self.localizationManager = localizationManager
    }
}

private extension StartStakingInfoSubtensorPreviewPresenter {
    func provideViewModel() {
        guard let previewData else {
            return
        }

        let locale = localizationManager.selectedLocale
        let viewModel = viewModelFactory.createViewModel(
            from: previewData.strategies,
            locale: locale
        )
        let balance = "Available balance: \(previewData.availableBalance)"

        view?.didReceive(subtensorViewModel: .loaded(value: viewModel))
        view?.didReceive(balance: balance)
    }
}

extension StartStakingInfoSubtensorPreviewPresenter: StartStakingInfoSubtensorPresenterProtocol {
    func setup() {
        view?.didReceive(subtensorViewModel: .loading)
        interactor.setup()
    }

    func startStaking() {
        wireframe.showStrategies(from: view)
    }

    func chooseManually() {
        wireframe.showManualStaking(from: view)
    }

    func refreshContent() {
        provideViewModel()
    }
}

extension StartStakingInfoSubtensorPreviewPresenter: StartStakingInfoSubtensorPreviewInteractorOutputProtocol {
    func didReceive(previewData: SubtensorStakingPreviewData) {
        self.previewData = previewData
        provideViewModel()
    }

    func didReceivePreview(error _: Error) {
        wireframe.presentLoadError(from: view) { [weak self] in
            self?.interactor.retry()
        }
    }
}
