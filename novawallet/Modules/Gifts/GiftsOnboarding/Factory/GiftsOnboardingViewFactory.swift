import Foundation
import Foundation_iOS

struct GiftsOnboardingViewFactory {
    static func createView(
        stateObservable: AssetListModelObservable,
        transferCompletion: @escaping TransferCompletionClosure,
        buyTokensClosure: @escaping BuyTokensClosure
    ) -> GiftsOnboardingViewProtocol? {
        let wireframe = GiftsOnboardingWireframe(
            stateObservable: stateObservable,
            transferCompletion: transferCompletion,
            buyTokensClosure: buyTokensClosure
        )
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
