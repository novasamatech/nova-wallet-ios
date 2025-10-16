import UIKit

final class GiftsOnboardingInteractor {
    weak var presenter: GiftsOnboardingInteractorOutputProtocol?
}

extension GiftsOnboardingInteractor: GiftsOnboardingInteractorInputProtocol {}