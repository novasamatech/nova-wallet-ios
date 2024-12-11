import UIKit

final class SwapRouteDetailsInteractor {
    weak var presenter: SwapRouteDetailsInteractorOutputProtocol?
}

extension SwapRouteDetailsInteractor: SwapRouteDetailsInteractorInputProtocol {}
