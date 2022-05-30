import Foundation

final class ParaStkCollatorsSearchWireframe: ParaStkCollatorsSearchWireframeProtocol {
    func complete(on view: ParaStkCollatorsSearchViewProtocol?) {
        view?.controller.navigationController?.popToRootViewController(animated: true)
    }

    func showCollatorInfo(
        from _: ParaStkCollatorsSearchViewProtocol?,
        collatorInfo _: CollatorSelectionInfo
    ) {}
}
