import Foundation

final class SubtensorValidatorFiltersWireframe: ValidatorFiltersWireframeProtocol {
    func complete(from view: SubtensorValidatorFiltersViewProtocol?) {
        view?.controller.navigationController?.popViewController(animated: true)
    }
}
