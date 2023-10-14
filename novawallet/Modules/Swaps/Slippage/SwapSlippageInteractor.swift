import UIKit

final class SwapSlippageInteractor {
    weak var presenter: SwapSlippageInteractorOutputProtocol?
}

extension SwapSlippageInteractor: SwapSlippageInteractorInputProtocol {}
