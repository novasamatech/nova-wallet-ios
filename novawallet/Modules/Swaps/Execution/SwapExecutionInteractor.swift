import UIKit

final class SwapExecutionInteractor {
    weak var presenter: SwapExecutionInteractorOutputProtocol?
}

extension SwapExecutionInteractor: SwapExecutionInteractorInputProtocol {}
