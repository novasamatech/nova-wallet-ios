import Foundation

protocol GiftsOnboardingViewProtocol: ControllerBackedProtocol {
    func didReceive(viewModel: GiftsOnboardingViewModel)
}

protocol GiftsOnboardingPresenterProtocol: AnyObject {
    func setup()
    func activateLearnMore()
    func proceed()
}

protocol GiftsOnboardingWireframeProtocol: WebPresentable, ErrorPresentable, AlertPresentable {
    func showCreateGift(from view: GiftsOnboardingViewProtocol?)
}
