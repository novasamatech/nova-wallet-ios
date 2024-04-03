import UIKit

final class OnboardingWalletReadyInteractor {
    weak var presenter: OnboardingWalletReadyInteractorOutputProtocol?
}

extension OnboardingWalletReadyInteractor: OnboardingWalletReadyInteractorInputProtocol {}
