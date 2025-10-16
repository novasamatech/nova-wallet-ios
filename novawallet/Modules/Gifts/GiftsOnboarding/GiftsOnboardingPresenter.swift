import Foundation
import Foundation_iOS

final class GiftsOnboardingPresenter {
    weak var view: GiftsOnboardingViewProtocol?
    
    let wireframe: GiftsOnboardingWireframeProtocol
    let interactor: GiftsOnboardingInteractorInputProtocol
    let viewModelFactory: GiftsOnboardingViewModelFactoryProtocol
    let learnMoreUrl: URL
    
    init(
        interactor: GiftsOnboardingInteractorInputProtocol,
        wireframe: GiftsOnboardingWireframeProtocol,
        viewModelFactory: GiftsOnboardingViewModelFactoryProtocol,
        learnMoreUrl: URL,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.interactor = interactor
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
        interactor.setup()
    }
    
    func activateLearnMore() {
        guard let view = view else {
            return
        }
        
        wireframe.showWeb(
            url: learnMoreUrl,
            from: view,
            style: .automatic
        )
    }
    
    func proceed() {
        wireframe.proceed(from: view)
    }
}

// MARK: - GiftsOnboardingInteractorOutputProtocol

extension GiftsOnboardingPresenter: GiftsOnboardingInteractorOutputProtocol {
    func didCompleteSetup() {
        provideViewModel()
    }
}

// MARK: - Localizable

extension GiftsOnboardingPresenter: Localizable {
    func applyLocalization() {
        if let view = view, view.isSetup {
            provideViewModel()
        }
    }
}
