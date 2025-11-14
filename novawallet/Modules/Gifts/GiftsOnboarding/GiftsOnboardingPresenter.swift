import Foundation
import Foundation_iOS

final class GiftsOnboardingPresenter {
    weak var view: GiftsOnboardingViewProtocol?

    let wireframe: GiftsOnboardingWireframeProtocol
    let viewModelFactory: GiftsOnboardingViewModelFactoryProtocol
    let learnMoreUrl: URL

    init(
        wireframe: GiftsOnboardingWireframeProtocol,
        viewModelFactory: GiftsOnboardingViewModelFactoryProtocol,
        learnMoreUrl: URL,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory
        self.learnMoreUrl = learnMoreUrl
        self.localizationManager = localizationManager
    }
}

// MARK: - Private

private extension GiftsOnboardingPresenter {
    func provideViewModel() {
        let viewModel = viewModelFactory.createViewModel(locale: selectedLocale)
        view?.didReceive(viewModel: viewModel)
    }
}

// MARK: - GiftsOnboardingPresenterProtocol

extension GiftsOnboardingPresenter: GiftsOnboardingPresenterProtocol {
    func setup() {
        provideViewModel()
    }

    func activateLearnMore() {
        guard let view else { return }

        wireframe.showWeb(
            url: learnMoreUrl,
            from: view,
            style: .automatic
        )
    }

    func proceed() {
        wireframe.showCreateGift(from: view)
    }
}

// MARK: - Localizable

extension GiftsOnboardingPresenter: Localizable {
    func applyLocalization() {
        guard let view, view.isSetup else { return }

        provideViewModel()
    }
}
