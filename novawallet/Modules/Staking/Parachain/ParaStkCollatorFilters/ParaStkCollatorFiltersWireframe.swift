import Foundation

final class ParaStkCollatorFiltersWireframe: ParaStkCollatorFiltersWireframeProtocol {
    func close(view: ParaStkCollatorFiltersViewProtocol?) {
        view?.controller.navigationController?.popViewController(animated: true)
    }
}
