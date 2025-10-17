import Foundation
import Foundation_iOS

struct GiftsOnboardingViewFactory {
    static func createView() -> GiftsOnboardingViewProtocol? {
        let wireframe = GiftsOnboardingWireframe()
        let viewModelFactory = GiftsOnboardingViewModelFactory()

        let presenter = GiftsOnboardingPresenter(
            wireframe: wireframe,
            viewModelFactory: viewModelFactory,
            learnMoreUrl: ApplicationConfig.shared.giftsWikiURL,
            localizationManager: LocalizationManager.shared
        )

        let view = GiftsOnboardingViewController(presenter: presenter)

        presenter.view = view

        return view
    }
}
