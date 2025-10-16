import Foundation

protocol GiftsOnboardingViewProtocol: ControllerBackedProtocol {
    func didReceive(viewModel: GiftsOnboardingViewModel)
}

protocol GiftsOnboardingPresenterProtocol: AnyObject {
    func setup()
    func activateLearnMore()
    func proceed()
}

protocol GiftsOnboardingInteractorInputProtocol: AnyObject {
    func setup()
}

protocol GiftsOnboardingInteractorOutputProtocol: AnyObject {
    func didCompleteSetup()
}

protocol GiftsOnboardingWireframeProtocol: WebPresentable, ErrorPresentable {
    func proceed(from view: GiftsOnboardingViewProtocol?)
}
