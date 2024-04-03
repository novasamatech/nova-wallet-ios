import Foundation

final class OnboardingWalletReadyPresenter {
    weak var view: OnboardingWalletReadyViewProtocol?
    let wireframe: OnboardingWalletReadyWireframeProtocol
    let interactor: OnboardingWalletReadyInteractorInputProtocol

    let walletName: String

    init(
        interactor: OnboardingWalletReadyInteractorInputProtocol,
        wireframe: OnboardingWalletReadyWireframeProtocol,
        walletName: String
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.walletName = walletName
    }
}

extension OnboardingWalletReadyPresenter: OnboardingWalletReadyPresenterProtocol {
    func setup() {
        view?.didReceive(walletName: walletName)
    }

    func applyCloudBackup() {}

    func applyManualBackup() {}
}

extension OnboardingWalletReadyPresenter: OnboardingWalletReadyInteractorOutputProtocol {}
