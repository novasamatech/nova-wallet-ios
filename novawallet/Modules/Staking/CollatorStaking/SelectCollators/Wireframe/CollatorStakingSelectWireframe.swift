import Foundation

class CollatorStakingSelectWireframe {
    func close(view: CollatorStakingSelectViewProtocol?) {
        view?.controller.navigationController?.popViewController(animated: true)
    }
}
