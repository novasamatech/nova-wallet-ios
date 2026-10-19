import Foundation

final class SubtensorValidatorFiltersWireframe: SubtensorValidatorFiltersWireframeProtocol {
    func complete(from view: SubtensorValidatorFiltersViewProtocol?) {
        view?.controller.navigationController?.popViewController(animated: true)
    }
}
