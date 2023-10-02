import UIKit

final class SwapSetupInteractor {
    weak var presenter: SwapSetupInteractorOutputProtocol?
}

extension SwapSetupInteractor: SwapSetupInteractorInputProtocol {}
