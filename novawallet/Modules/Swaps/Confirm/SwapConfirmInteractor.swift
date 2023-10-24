import UIKit

final class SwapConfirmInteractor {
    weak var presenter: SwapConfirmInteractorOutputProtocol?
}

extension SwapConfirmInteractor: SwapConfirmInteractorInputProtocol {}
