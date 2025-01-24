import Foundation

class CollatorStakingSelectWireframe {
    func close(view: ParaStkSelectCollatorsViewProtocol?) {
        view?.controller.navigationController?.popViewController(animated: true)
    }
}
